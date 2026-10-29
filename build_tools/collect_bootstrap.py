#!/usr/bin/env python3
"""Collect exactly the Bootstrap DEBs pinned in requirements files."""
import argparse
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


class Error(Exception):
    pass


PIN = re.compile(r"([a-z0-9][a-z0-9+.-]+)\s*==\s*([0-9][A-Za-z0-9.+:~\-]*)")


def read_requirements(files, stack=()):
    pins = {}
    for filename in files:
        path = Path(filename).resolve()
        if path in stack:
            raise Error(f"Requirements include cycle: {path}")
        for number, line in enumerate(path.read_text().splitlines(), 1):
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            if line.startswith("-r "):
                additions = read_requirements([path.parent / line[3:].strip()], (*stack, path))
            else:
                match = PIN.fullmatch(line)
                if not match:
                    raise Error(f"{path}:{number}: expected package==Debian-version or -r file")
                additions = {match[1]: match[2]}
            for name, version in additions.items():
                if name in pins:
                    raise Error(f"{path}:{number}: duplicate requirement for {name}")
                pins[name] = version
    if not pins:
        raise Error("Bootstrap requirements are empty")
    return pins


def fields(path):
    result = subprocess.run(
        ["dpkg-deb", "-f", str(path), "Package", "Version", "Architecture"],
        text=True, capture_output=True,
    )
    if result.returncode:
        raise Error(f"Cannot read {path}: {result.stderr.strip()}")
    control = dict(line.split(": ", 1) for line in result.stdout.splitlines() if ": " in line)
    if not all(control.get(k) for k in ("Package", "Version", "Architecture")):
        raise Error(f"Missing package identity in {path}")
    return control


def digest(path):
    with path.open("rb") as stream:
        value = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.digest()


def collect(requirements, packages, architecture, output):
    pins = read_requirements(requirements)
    packages, output = Path(packages).resolve(), Path(output)
    if output.is_symlink():
        raise Error(f"Output must not be a symlink: {output}")
    output = output.resolve()
    if not packages.is_dir():
        raise Error(f"Package directory does not exist: {packages}")
    if packages == output or output in packages.parents:
        raise Error("Output must not contain the package input directory")
    candidates = {name: [] for name in pins}
    # Build outputs are <recipe>/*.deb; also accept a flat DEB directory.
    for path in sorted(set(packages.glob("*.deb")) | set(packages.glob("*/*.deb"))):
        if output == path.parent.resolve() or path.parent.name in ("work", "strap"):
            continue
        control = fields(path)
        if control["Package"] in candidates:
            candidates[control["Package"]].append((path, control))
    selected = []
    for name, version in pins.items():
        matches = [(p, c) for p, c in candidates[name]
                   if c["Version"] == version and c["Architecture"] in (architecture, "all")]
        if not matches:
            available = ", ".join(sorted({f'{c["Version"]} ({c["Architecture"]})'
                                          for _, c in candidates[name]})) or "none"
            raise Error(f"Missing {name}=={version} for {architecture}; available: {available}")
        if len({digest(p) for p, _ in matches}) != 1:
            raise Error(f"Conflicting DEBs for {name}=={version}: " + ", ".join(str(p) for p, _ in matches))
        path, control = matches[0]
        selected.append((path, f'{name}_{version}_{control["Architecture"]}.deb'))
    # Validate every member before replacing the previous collected set.
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".bootstrap-", dir=output.parent) as temporary:
        stage = Path(temporary) / "selected"
        stage.mkdir()
        for source, name in selected:
            shutil.copy2(source, stage / name)
        (stage / "packages.list").write_text("".join(name + "\n" for _, name in selected))
        if output.exists():
            shutil.rmtree(output)
        stage.rename(output)
    return len(selected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--requirements", action="append", required=True, type=Path)
    parser.add_argument("--packages", required=True, type=Path)
    parser.add_argument("--architecture", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        count = collect(args.requirements, args.packages, args.architecture, args.output)
    except (Error, OSError) as exc:
        parser.exit(1, f"Bootstrap collection failed: {exc}\n")
    print(f"Collected {count} pinned Bootstrap packages for {args.architecture}.")


if __name__ == "__main__":
    main()
