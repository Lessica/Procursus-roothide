#!/usr/bin/env python3
"""Validate accepted Debs and stage them for the existing Makefile Bootstrap recipe.

This helper does not build, unpack, sign, or assemble a Bootstrap. The caller
supplies the existing recipe's PKGS list and an explicit candidate manifest.
"""
import argparse
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile


def run(*args):
    return subprocess.check_output(args)


def fields(text):
    result = {}
    key = None
    for line in text.splitlines():
        if line.startswith((' ', '\t')) and key:
            result[key] += '\n' + line
        elif ':' in line:
            key, value = line.split(':', 1)
            result[key] = value.strip()
    return result


def relation(text):
    match = re.fullmatch(r'\s*([a-z0-9][a-z0-9+.-]*)(?::(any|native|iphoneos-arm64e))?\s*(?:\((<<|<=|=|>=|>>)\s*([^()]+)\))?\s*', text)
    if not match:
        raise ValueError('Unsupported dependency syntax: ' + text)
    return match[1], match[3], match[4]


def satisfies(version, operator, required):
    return not operator or (version is not None and subprocess.run(
        ['dpkg', '--compare-versions', version, operator, required], check=False).returncode == 0)


def provides(control):
    values = {control['Package']: control['Version']}
    for value in control.get('Provides', '').split(','):
        if value.strip():
            name, op, version = relation(value)
            if op not in (None, '='):
                raise ValueError('Invalid Provides: ' + value)
            values[name] = version
    return values


def matches(control, requirement):
    name, op, version = relation(requirement)
    available = provides(control)
    return name in available and satisfies(available[name], op, version)


def safe_name(name):
    while name.startswith('./'):
        name = name[2:]
    if name in ('', '.'):
        return ''
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts:
        raise ValueError('Unsafe archive member: ' + name)
    return str(path)


# These are supplied by Relaxin's first-install sequence, not by this tarball.
# firmware is generated from the device OS; 16.5 is Relaxin's minimum OS.
EXTERNAL = [
    {'Package': 'firmware', 'Version': '16.5',
     'reason': 'darwintools firmware generates the actual device firmware package during prep; Relaxin supports iOS >=16.5.'},
    {'Package': 'org.coolstar.sileo', 'Version': '2.1',
     'reason': 'Relaxin installs a selected compatible package manager after prep. Sileo is one accepted alternative, not an archive member.'},
    {'Package': 'libkrw0-dopamine', 'Version': '0:2.0.6:compat', 'Provides': 'libkrw0-plugin',
     'reason': 'Relaxin finalizer installs its matching libkrw0-dopamine plugin after prep; the plugin is not embedded in Bootstrap.'},
]


def baseline_versions(path):
    if not path:
        return {}
    with tarfile.open(fileobj=io.BytesIO(run('zstd', '-qdc', path)), mode='r:') as archive:
        statuses = [entry for entry in archive if safe_name(entry.name) == 'Library/dpkg/status']
        if len(statuses) != 1 or not statuses[0].isfile():
            raise ValueError('Baseline must contain exactly one Library/dpkg/status')
        text = archive.extractfile(statuses[0]).read().decode()
    result = {}
    for paragraph in re.split(r'\n\s*\n', text):
        control = fields(paragraph)
        if control.get('Status') == 'install ok installed':
            if control['Package'] in result:
                raise ValueError('Duplicate baseline package: ' + control['Package'])
            result[control['Package']] = control['Version']
    if not result:
        raise ValueError('Baseline has no installed packages')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('candidates', 'destination', 'packages', 'manifest'):
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--baseline')
    args = parser.parse_args()
    requested = []
    source_dirs = {}
    for pattern in args.packages.split():
        match = re.fullmatch(r'([A-Za-z0-9+._-]+)/([a-z0-9][a-z0-9+.-]*)_\*\.deb', pattern)
        if not match:
            raise ValueError('Unsupported PKGS pattern: ' + pattern)
        directory, package = match.groups()
        if package in requested:
            raise ValueError('Duplicate requested package: ' + package)
        requested.append(package)
        source_dirs[package] = directory
    if not requested:
        raise ValueError('Empty PKGS list')
    baseline = baseline_versions(args.baseline)
    missing = sorted(set(baseline) - set(requested))
    if missing:
        raise ValueError('PKGS omits baseline members: ' + ', '.join(missing))
    artifacts = json.loads(Path(args.candidates).read_text())['artifacts']
    def inspect(artifact):
        return artifact, fields(run('dpkg-deb', '-f', artifact['path']).decode())
    controls = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        for artifact, control in executor.map(inspect, artifacts):
            package = control['Package']
            if package in controls:
                raise ValueError('Ambiguous candidate package: ' + package)
            controls[package] = artifact, control
    for package in requested:
        if package not in controls:
            raise ValueError('Missing Bootstrap member: ' + package)
        if package in baseline and not satisfies(controls[package][1]['Version'], '>=', baseline[package]):
            raise ValueError('Refusing downgrade: ' + package)
    selected = list(requested)
    edges = []
    for package in selected:
        control = controls[package][1]
        for field in ('Pre-Depends', 'Depends'):
            for group in filter(str.strip, control.get(field, '').split(',')):
                alternatives = group.split('|')
                installed = next((name for name in selected if any(matches(controls[name][1], alt) for alt in alternatives)), None)
                external = next((item for item in EXTERNAL if any(matches(item, alt) for alt in alternatives)), None)
                if installed:
                    target, kind = installed, 'archive'
                elif external:
                    target, kind = external['Package'], 'external'
                else:
                    raise ValueError('Dependency absent from Makefile Bootstrap members: %s %s %s' %
                                     (package, field, group))
                edges.append({'package': package, 'field': field, 'requirement': group.strip(), 'provider': target, 'kind': kind})
    for package in selected:
        control = controls[package][1]
        for field in ('Conflicts', 'Breaks'):
            for group in filter(str.strip, control.get(field, '').split(',')):
                for other in selected:
                    if other != package and any(matches(controls[other][1], alt) for alt in group.split('|')):
                        raise ValueError('%s %s %s (%s)' % (package, field, other, group))
    destination = Path(args.destination)
    records = []
    payloads = []
    for package in selected:
        artifact, control = controls[package]
        if control['Architecture'] not in ('iphoneos-arm64e', 'all'):
            raise ValueError('Wrong architecture: ' + package)
        data = Path(artifact['path']).read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if len(data) != artifact['size'] or digest != artifact['sha256']:
            raise ValueError('Candidate checksum/size mismatch: ' + package)
        directory = source_dirs.get(package, artifact.get('source_directory'))
        if not directory or not re.fullmatch(r'[A-Za-z0-9+._-]+', directory) or directory in ('.', '..'):
            raise ValueError('Invalid source directory for ' + package)
        relative = directory + '/' + Path(artifact['path']).name
        if not relative.endswith('.deb') or '\n' in relative:
            raise ValueError('Invalid Deb filename: ' + relative)
        target = destination / relative
        if target.parent.is_symlink() or target.is_symlink():
            raise ValueError('Refusing symlink staging path: ' + str(target))
        if target.exists() and target.read_bytes() != data:
            raise ValueError('Different Deb already staged: ' + str(target))
        records.append({'package': package, 'version': control['Version'], 'baseline_version': baseline.get(package),
                        'path': artifact['path'], 'staged_path': relative, 'sha256': digest, 'size': len(data)})
        payloads.append((target, data))
    for target, data in payloads:
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            target.write_bytes(data)
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'selected-packages.list').write_text(''.join(record['staged_path'] + '\n' for record in records))
    report = {'requested_members': requested, 'members': records, 'dependency_edges': edges,
              'external_providers': EXTERNAL, 'external_requirements': [edge for edge in edges if edge['kind'] == 'external'],
              'baseline': args.baseline, 'baseline_sha256': hashlib.sha256(Path(args.baseline).read_bytes()).hexdigest() if args.baseline else None,
              'closure': 'complete subject to declared Relaxin runtime providers',
              'package_scripts_executed': False}
    Path(args.manifest).parent.mkdir(parents=True, exist_ok=True)
    Path(args.manifest).write_text(json.dumps(report, indent=2) + '\n')
    print('%d requested + %d dependency packages staged; %d external dependency edges' %
          (len(requested), len(selected) - len(requested), len(report['external_requirements'])))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
