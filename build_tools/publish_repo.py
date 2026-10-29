#!/usr/bin/env python3
"""Incrementally archive platform build outputs into a local Debian APT repository.

The tool never builds packages and never uploads anything. It copies Debian
packages from a build_dist tree into a static pool, generates indexes with
apt-ftparchive, signs Release/InRelease with GnuPG, and can verify the result
(including the Bootstrap) over local HTTP with apt-get.

Linux is the supported host: apt-ftparchive, xz, zstd, gpg, gpgv, dpkg-deb and
apt-get are required for the commands that use them.
"""
from __future__ import annotations

import argparse
import contextlib
import fcntl
import functools
import getpass
import hashlib
import http.server
import io
import json
import lzma
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
from pathlib import Path

ORIGIN = "OwnGoal Stripe"
LABEL = "OwnGoal Stripe"
SUITE_DEFAULT = "1900"
COMPONENT_DEFAULT = "main"
ARCH_DEFAULT = "iphoneos-arm64e"
POOL_TARGET_DEFAULT = "iphoneos-arm64-roothide"
URI_DEFAULT = "https://stripe.owngoal.dev"
DESCRIPTION = "Distribution of essential tools for iPhoneOS"


class Fail(Exception):
    """A user-facing failure."""


# ---------------------------------------------------------------------------
# Process and file helpers


def run(args, *, cwd=None, check=True, timeout=300):
    proc = subprocess.run(
        [str(a) for a in args],
        cwd=None if cwd is None else str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
    )
    if check and proc.returncode:
        stderr = proc.stderr.decode("utf-8", "replace").strip()
        raise Fail(f"{' '.join(str(a) for a in args)} failed ({proc.returncode}): {stderr}")
    return proc


def run_to_file(args, path, *, cwd=None, stdin_path=None, timeout=600):
    """Run a command and atomically place its stdout at path."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + f".tmp.{os.getpid()}")
    stdin = None
    try:
        with open(tmp, "wb") as out:
            if stdin_path is None:
                stdin = subprocess.DEVNULL
            else:
                stdin = open(stdin_path, "rb")
            proc = subprocess.run(
                [str(a) for a in args],
                cwd=None if cwd is None else str(cwd),
                stdin=stdin,
                stdout=out,
                stderr=subprocess.PIPE,
                timeout=timeout,
            )
        if proc.returncode:
            stderr = proc.stderr.decode("utf-8", "replace").strip()
            raise Fail(f"{' '.join(str(a) for a in args)} failed ({proc.returncode}): {stderr}")
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    finally:
        if stdin not in (None, subprocess.DEVNULL):
            stdin.close()
        if tmp.exists():
            tmp.unlink()


def require_tools(names):
    missing = [name for name in names if shutil.which(name) is None]
    if missing:
        raise Fail("missing required tools: " + ", ".join(missing))


def hash_file(path, *, noatime=False):
    flags = os.O_RDONLY
    if noatime:
        flags |= getattr(os, "O_NOATIME", 0)
    try:
        fd = os.open(path, flags)
    except PermissionError:
        fd = os.open(path, os.O_RDONLY)
    digest = hashlib.sha256()
    with os.fdopen(fd, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def atomic_copy(src, dst):
    src, dst = Path(src), Path(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=dst.name + ".", dir=str(dst.parent))
    os.close(fd)
    tmp = Path(tmp_name)
    try:
        shutil.copy2(src, tmp)
        os.chmod(tmp, 0o644)
        os.replace(tmp, dst)
    finally:
        if tmp.exists():
            tmp.unlink()


def atomic_write_bytes(path, data, mode=0o644):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    os.close(fd)
    tmp = Path(tmp_name)
    try:
        with open(tmp, "wb") as handle:
            handle.write(data)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def parse_deb822(text):
    """Parse Deb822 stanzas into a list of dictionaries."""
    stanzas = []
    current = {}
    key = None
    for line in text.splitlines():
        if not line.strip():
            if current:
                stanzas.append(current)
                current = {}
                key = None
            continue
        if line[0] in " \t" and key:
            current[key] += "\n" + line.strip()
        elif ":" in line:
            key, value = line.split(":", 1)
            current[key] = value.strip()
    if current:
        stanzas.append(current)
    return stanzas


def single_fields(text):
    stanzas = parse_deb822(text)
    if len(stanzas) != 1:
        raise Fail(f"expected one Deb822 stanza, found {len(stanzas)}")
    return stanzas[0]


# ---------------------------------------------------------------------------
# Package discovery and incremental archiving


def discover_debs(packages_dir):
    packages_dir = Path(packages_dir)
    result = []
    for recipe in sorted(packages_dir.iterdir()):
        if not recipe.is_dir() or recipe.name == "work" or recipe.name.startswith("."):
            continue
        for deb in sorted(recipe.iterdir()):
            if deb.is_file() and not deb.is_symlink() and deb.suffix == ".deb":
                result.append((recipe.name, deb))
    return result


def pool_relative(component, pool_target, cfver, recipe, name):
    return Path("pool") / component / pool_target / cfver / recipe / name


def archive_packages(packages_dir, repo, *, component, pool_target, cfver,
                     replace=False, prune=False, dry_run=False):
    packages_dir = Path(packages_dir).resolve()
    repo = Path(repo).resolve()
    if not packages_dir.is_dir():
        raise Fail(f"package directory does not exist: {packages_dir}")
    pool_root = repo / "pool" / component / pool_target / cfver

    source = {}
    for recipe, deb in discover_debs(packages_dir):
        source[pool_relative(component, pool_target, cfver, recipe, deb.name)] = deb

    actions = []
    conflicts = []
    cache = {}

    for rel, src in sorted(source.items()):
        dst = repo / rel
        if not dst.exists():
            actions.append(("add", rel, src, dst, None))
            continue
        if not dst.is_file():
            conflicts.append(f"{rel}: destination is not a regular file")
            continue
        src_hash = cache.get(str(src)) or hash_file(src)
        cache[str(src)] = src_hash
        dst_hash = cache.get(str(dst)) or hash_file(dst, noatime=True)
        cache[str(dst)] = dst_hash
        if src_hash == dst_hash:
            actions.append(("skip", rel, src, dst, dst_hash))
        elif replace:
            actions.append(("replace", rel, src, dst, src_hash))
        else:
            conflicts.append(
                f"{rel}: same filename has different content "
                f"(source {src_hash[:12]}, destination {dst_hash[:12]})"
            )

    if conflicts:
        raise Fail(
            "refusing to overwrite existing packages; bump the package version "
            "or pass --replace:\n  " + "\n  ".join(conflicts)
        )

    added = replaced = skipped = 0
    for action, rel, src, dst, known_hash in actions:
        if action == "skip":
            skipped += 1
            continue
        if action == "add":
            added += 1
        else:
            replaced += 1
        if dry_run:
            continue
        atomic_copy(src, dst)
        cache[str(dst)] = known_hash or hash_file(src)

    removed = []
    if prune and pool_root.is_dir():
        wanted = set(source)
        existing = {
            p.relative_to(repo)
            for p in pool_root.rglob("*.deb")
            if p.is_file() and not p.is_symlink()
        }
        for rel in sorted(existing - wanted):
            removed.append(rel)
            if not dry_run:
                (repo / rel).unlink()
                cache.pop(str(repo / rel), None)
        if not dry_run:
            directories = sorted(
                (p for p in pool_root.rglob("*") if p.is_dir()),
                key=lambda p: len(p.parts),
                reverse=True,
            )
            for directory in directories:
                try:
                    directory.rmdir()
                except OSError:
                    pass

    return {
        "added": added,
        "replaced": replaced,
        "skipped": skipped,
        "removed": removed,
        "total": len(source),
        "cache": cache,
    }


def pool_manifest(repo, component, pool_target, cfver, cache=None):
    repo = Path(repo).resolve()
    cache = cache if cache is not None else {}
    pool_root = repo / "pool" / component / pool_target / cfver
    manifest = {}
    if not pool_root.is_dir():
        return manifest
    for path in sorted(pool_root.rglob("*.deb")):
        if not path.is_file() or path.is_symlink():
            continue
        rel = str(path.relative_to(repo))
        digest = cache.get(str(path)) or hash_file(path, noatime=True)
        cache[str(path)] = digest
        manifest[rel] = {"size": path.stat().st_size, "sha256": digest}
    return manifest


# ---------------------------------------------------------------------------
# State, locking and index freshness


def state_config(repo, suite, cfver, component, arch, pool_target):
    return {
        "repo": str(Path(repo).resolve()),
        "suite": suite,
        "cfver": cfver,
        "component": component,
        "arch": arch,
        "pool_target": pool_target,
    }


def state_path(state_dir, config):
    digest = hashlib.sha256(
        json.dumps(config, sort_keys=True).encode("utf-8")
    ).hexdigest()[:16]
    return Path(state_dir) / f"{digest}.json"


def load_state(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return None


def save_state(path, data):
    atomic_write_bytes(
        Path(path), (json.dumps(data, indent=2, sort_keys=True) + "\n").encode("utf-8")
    )


@contextlib.contextmanager
def publish_lock(state_dir):
    state_dir = Path(state_dir)
    state_dir.mkdir(parents=True, exist_ok=True)
    lock_path = state_dir / "publish.lock"
    handle = open(lock_path, "a+")
    try:
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            raise Fail(f"another publish run holds the lock: {lock_path}")
        yield
    finally:
        try:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        finally:
            handle.close()


def index_paths(repo, suite, component, arch):
    dist = Path(repo) / "dists" / suite
    binary = dist / component / f"binary-{arch}"
    return {
        "dist": dist,
        "binary": binary,
        "release": dist / "Release",
        "release_gpg": dist / "Release.gpg",
        "inrelease": dist / "InRelease",
        "packages": binary / "Packages",
        "packages_xz": binary / "Packages.xz",
        "packages_zst": binary / "Packages.zst",
        "binary_release": binary / "Release",
        "contents": dist / component / f"Contents-{arch}",
        "contents_xz": dist / component / f"Contents-{arch}.xz",
        "contents_zst": dist / component / f"Contents-{arch}.zst",
    }


def should_rebuild(state, manifest, signing_key, required, force=False):
    if force:
        return True, "forced"
    if state is None:
        return True, "no previous state"
    if state.get("signing_key") != signing_key:
        return True, "signing key changed"
    if state.get("packages") != manifest:
        return True, "package set changed"
    missing = [str(path) for path in required if not Path(path).is_file()]
    if missing:
        return True, "index files missing: " + ", ".join(missing)
    return False, "package set unchanged"


# ---------------------------------------------------------------------------
# Signing and index generation


def signing_fingerprint(signing_key):
    proc = run(
        ["gpg", "--batch", "--with-colons", "--list-secret-keys", signing_key],
        check=False,
    )
    if proc.returncode:
        stderr = proc.stderr.decode("utf-8", "replace").strip()
        raise Fail(f"signing key is not available: {signing_key}: {stderr}")
    for line in proc.stdout.decode("utf-8", "replace").splitlines():
        if line.startswith("fpr:"):
            return line.split(":")[9]
    raise Fail(f"no fingerprint found for signing key: {signing_key}")


def keyring_fingerprints(keyring):
    keyring = Path(keyring)
    if not keyring.is_file():
        raise Fail(f"keyring does not exist: {keyring}")
    proc = run(["gpg", "--batch", "--with-colons", "--show-keys", keyring])
    return [
        line.split(":")[9]
        for line in proc.stdout.decode("utf-8", "replace").splitlines()
        if line.startswith("fpr:")
    ]


def apt_config_text(*, suite, arch, component, include_suite):
    lines = [
        "APT {",
        "    FTPArchive {",
        "        Release {",
        f'            Origin "{ORIGIN}";',
        f'            Label "{LABEL}";',
        f'            Architectures "{arch}";',
    ]
    if include_suite:
        lines += [
            "            Suite stable;",
            "            Version 1.0;",
            f'            Codename "{suite}";',
            f'            Components "{component}";',
            f'            Description "{DESCRIPTION}";',
        ]
    lines += [
        "        };",
        "    };",
        "};",
        "",
    ]
    return "\n".join(lines)


def generate_index(repo, *, suite, cfver, component, arch, pool_target,
                   signing_key, state_dir, log=print):
    require_tools(["apt-ftparchive", "xz", "zstd"])
    repo = Path(repo).resolve()
    state_dir = Path(state_dir).resolve()
    state_dir.mkdir(parents=True, exist_ok=True)
    pool_rel = Path("pool") / component / pool_target / cfver
    pool_root = repo / pool_rel
    if not pool_root.is_dir() or not any(pool_root.rglob("*.deb")):
        raise Fail(f"no Debian packages found under {pool_root}")

    dist_parent = repo / "dists"
    dist_parent.mkdir(parents=True, exist_ok=True)
    staging = dist_parent / f".staging-{os.getpid()}-{time.time_ns()}"
    work = dist_parent / f".work-{os.getpid()}-{time.time_ns()}"
    binary = staging / component / f"binary-{arch}"
    try:
        # A suite is shared by platforms: update only the selected architecture.
        previous = dist_parent / suite
        if previous.is_dir():
            shutil.copytree(previous, staging)
            for name in ("Release", "Release.gpg", "InRelease"):
                (staging / name).unlink(missing_ok=True)
        if binary.exists():
            shutil.rmtree(binary)
        binary.mkdir(parents=True)
        work.mkdir()
        basic_conf = work / "basic.conf"
        suite_conf = work / "suite.conf"
        basic_conf.write_text(
            apt_config_text(
                suite=suite, arch=arch, component=component, include_suite=False
            )
        )
        suite_conf.write_text(
            apt_config_text(
                suite=suite,
                arch=" ".join(sorted({p.name.removeprefix("binary-")
                                      for p in staging.glob("*/binary-*") if p.is_dir()})),
                component=" ".join(sorted({p.parent.name
                                           for p in staging.glob("*/binary-*") if p.is_dir()})),
                include_suite=True
            )
        )

        db = state_dir / "repocache.db"
        apt = [
            "apt-ftparchive",
            f"--db={db}",
            "-oAPT::FTPArchive::AlwaysStat=true",
        ]

        # Packages
        packages = binary / "Packages"
        log(f"packages  {pool_rel}")
        run_to_file(apt + ["packages", str(pool_rel)], packages, cwd=repo)
        run_to_file(["xz", "-c9", str(packages)], binary / "Packages.xz")
        run_to_file(["zstd", "-q", "-c19", str(packages)], binary / "Packages.zst")

        # Contents
        contents = staging / component / f"Contents-{arch}"
        log(f"contents  {pool_rel}")
        run_to_file(apt + ["contents", str(pool_rel)], contents, cwd=repo)
        run_to_file(["xz", "-c9", str(contents)], staging / component / f"Contents-{arch}.xz")
        run_to_file(["zstd", "-q", "-c19", str(contents)], staging / component / f"Contents-{arch}.zst")

        # Component Release
        binary_release = binary / "Release"
        run_to_file(
            apt + ["release", "-c", str(basic_conf), str(binary)],
            work / "binary-Release",
            cwd=repo,
        )
        os.chmod(work / "binary-Release", 0o644)
        os.replace(work / "binary-Release", binary_release)

        # Root Release
        root_release = staging / "Release"
        run_to_file(
            apt + ["release", "-c", str(suite_conf), str(staging)],
            work / "Release",
            cwd=repo,
        )
        os.chmod(work / "Release", 0o644)
        os.replace(work / "Release", root_release)

        # Signatures
        log("signing   Release")
        run(["gpg", "--batch", "--yes", "--detach-sign", "-u", signing_key,
             "-o", work / "Release.gpg", root_release])
        os.chmod(work / "Release.gpg", 0o644)
        os.replace(work / "Release.gpg", staging / "Release.gpg")
        run(["gpg", "--batch", "--yes", "--clearsign", "-u", signing_key,
             "-o", work / "InRelease", root_release])
        os.chmod(work / "InRelease", 0o644)
        os.replace(work / "InRelease", staging / "InRelease")

        swap_index(repo, suite, staging)
        staging = None
        log("index     replaced")
    finally:
        if staging is not None and staging.exists():
            shutil.rmtree(staging, ignore_errors=True)
        if work.exists():
            shutil.rmtree(work, ignore_errors=True)


def swap_index(repo, suite, staging):
    """Replace dists/<suite> with staging, restoring the old tree on failure."""
    dist_parent = Path(repo) / "dists"
    live = dist_parent / suite
    backup = dist_parent / f".old-{os.getpid()}-{time.time_ns()}"
    moved = False
    try:
        if live.exists():
            os.replace(live, backup)
            moved = True
        os.replace(staging, live)
    except Exception:
        if moved and backup.exists() and not live.exists():
            os.replace(backup, live)
        raise
    else:
        if backup.exists():
            shutil.rmtree(backup, ignore_errors=True)


# ---------------------------------------------------------------------------
# Verification


def digest_file(path, algorithm, *, noatime=False):
    flags = os.O_RDONLY
    if noatime:
        flags |= getattr(os, "O_NOATIME", 0)
    try:
        fd = os.open(path, flags)
    except PermissionError:
        fd = os.open(path, os.O_RDONLY)
    digest = hashlib.new(algorithm)
    with os.fdopen(fd, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def release_hash_sections(text):
    sections = {}
    current = None
    for line in text.splitlines():
        if line.endswith(":") and line[:-1] in ("MD5Sum", "SHA1", "SHA256", "SHA512"):
            current = line[:-1]
            sections[current] = []
        elif current and line.startswith(" "):
            parts = line.split()
            if len(parts) >= 3:
                sections[current].append((parts[0], int(parts[1]), " ".join(parts[2:])))
        elif line and not line.startswith(" "):
            current = None
    return sections


def verify_release_signature(dist, keyring):
    release = dist / "Release"
    inrelease = dist / "InRelease"
    release_gpg = dist / "Release.gpg"
    for path in (release, inrelease, release_gpg):
        if not path.is_file():
            raise Fail(f"missing release file: {path}")
    with tempfile.TemporaryDirectory() as tmp:
        common = ["gpgv", "--homedir", tmp, "--keyring", str(keyring)]
        run(common + [str(release_gpg), str(release)])
        payload = run(common + ["--output", "-", str(inrelease)]).stdout
        if payload != release.read_bytes():
            raise Fail("InRelease payload does not match Release")
    return release.read_text()


def verify_release(dist, suite, component, arch, text):
    fields = single_fields(text)
    expected = {
        "Origin": ORIGIN,
        "Label": LABEL,
        "Suite": "stable",
        "Codename": suite,
    }
    for key, value in expected.items():
        if fields.get(key) != value:
            raise Fail(f"Release {key} is {fields.get(key)!r}, expected {value!r}")
    if component not in fields.get("Components", "").split():
        raise Fail(f"Release Components does not include {component}")
    if arch not in fields.get("Architectures", "").split():
        raise Fail(f"Release Architectures does not include {arch}")

    sections = release_hash_sections(text)
    for required in ("SHA256", "SHA512"):
        if not sections.get(required):
            raise Fail(f"Release has no {required} section")
    names = {name for entries in sections.values() for _, _, name in entries}
    required_names = {
        f"{component}/binary-{arch}/Release",
        f"{component}/binary-{arch}/Packages",
        f"{component}/binary-{arch}/Packages.xz",
        f"{component}/binary-{arch}/Packages.zst",
        f"{component}/Contents-{arch}",
        f"{component}/Contents-{arch}.xz",
        f"{component}/Contents-{arch}.zst",
    }
    missing = required_names - names
    if missing:
        raise Fail("Release is missing index entries: " + ", ".join(sorted(missing)))

    algorithms = {"MD5Sum": "md5", "SHA1": "sha1", "SHA256": "sha256", "SHA512": "sha512"}
    for section, entries in sections.items():
        algorithm = algorithms[section]
        for expected_digest, expected_size, name in entries:
            target = (dist / name).resolve()
            try:
                target.relative_to(dist.resolve())
            except ValueError:
                raise Fail(f"Release references a path outside the suite: {name}")
            if not target.is_file():
                raise Fail(f"Release references a missing file: {name}")
            if target.stat().st_size != expected_size:
                raise Fail(f"Release size mismatch: {name}")
            if digest_file(target, algorithm) != expected_digest:
                raise Fail(f"Release {section} mismatch: {name}")


def verify_packages(repo, suite, component, arch, pool_target, cfver):
    binary = Path(repo) / "dists" / suite / component / f"binary-{arch}"
    packages = binary / "Packages"
    if not packages.is_file():
        raise Fail(f"missing Packages: {packages}")
    text = packages.read_text()
    records = parse_deb822(text)
    if not records:
        raise Fail("Packages is empty")

    try:
        uncompressed = lzma.decompress((binary / "Packages.xz").read_bytes())
    except lzma.LZMAError as error:
        raise Fail(f"Packages.xz is invalid: {error}")
    if uncompressed != packages.read_bytes():
        raise Fail("Packages.xz does not match Packages")
    zstd = run(["zstd", "-dc", str(binary / "Packages.zst")])
    if zstd.stdout != packages.read_bytes():
        raise Fail("Packages.zst does not match Packages")

    prefix = f"pool/{component}/{pool_target}/{cfver}/"
    seen = set()
    root = Path(repo).resolve()
    for record in records:
        for field in ("Package", "Version", "Architecture", "Filename", "Size"):
            if field not in record:
                raise Fail(f"Packages record is missing {field}: {record.get('Package')}")
        if record["Architecture"] not in (arch, "all"):
            raise Fail(
                f"unexpected architecture {record['Architecture']} for {record['Package']}"
            )
        identity = (record["Package"], record["Version"], record["Architecture"])
        if identity in seen:
            raise Fail(f"duplicate package record: {identity}")
        seen.add(identity)
        if not record["Filename"].startswith(prefix):
            raise Fail(f"package path does not follow the pool layout: {record['Filename']}")
        path = (root / record["Filename"]).resolve()
        try:
            path.relative_to(root)
        except ValueError:
            raise Fail(f"package path escapes the repository: {record['Filename']}")
        if not path.is_file():
            raise Fail(f"package file is missing: {record['Filename']}")
        if path.stat().st_size != int(record["Size"]):
            raise Fail(f"package size mismatch: {record['Filename']}")
        checks = (("MD5sum", "md5"), ("SHA1", "sha1"), ("SHA256", "sha256"), ("SHA512", "sha512"))
        for field, algorithm in checks:
            if field not in record:
                raise Fail(f"package is missing {field}: {record['Filename']}")
            if digest_file(path, algorithm) != record[field]:
                raise Fail(f"package {field} mismatch: {record['Filename']}")
        metadata = single_fields(run(["dpkg-deb", "-f", str(path)]).stdout.decode("utf-8", "replace"))
        for field in ("Package", "Version", "Architecture"):
            if metadata.get(field) != record[field]:
                raise Fail(f"package {field} does not match control: {record['Filename']}")
    return records


def newest_record(records):
    best = None
    for record in records:
        if best is None:
            best = record
            continue
        proc = run(
            ["dpkg", "--compare-versions", record["Version"], "gt", best["Version"]],
            check=False,
        )
        if proc.returncode == 0:
            best = record
    return best


def verify_keyring_package(repo, records, keyring):
    candidates = [r for r in records if r["Package"] == "procursus-keyring"]
    if not candidates:
        raise Fail("repository does not contain procursus-keyring")
    record = newest_record(candidates)
    path = Path(repo) / record["Filename"]
    proc = run(["dpkg-deb", "--fsys-tarfile", str(path)])
    embedded = None
    with tarfile.open(fileobj=io.BytesIO(proc.stdout), mode="r:") as archive:
        for member in archive:
            name = member.name[2:] if member.name.startswith("./") else member.name
            if name == "usr/share/keyrings/owngoal-procursus.gpg" and member.isfile():
                embedded = archive.extractfile(member).read()
                break
    if embedded != Path(keyring).read_bytes():
        raise Fail("procursus-keyring does not contain the repository public key")
    return record["Version"]


def normalize_member(name):
    while name.startswith("./"):
        name = name[2:]
    return name


def verify_bootstrap(bootstrap, keyring, repo, records, suite, component, arch, uri):
    bootstrap = Path(bootstrap)
    signature = Path(str(bootstrap) + ".asc")
    if not bootstrap.is_file():
        raise Fail(f"Bootstrap does not exist: {bootstrap}")
    if not signature.is_file():
        raise Fail(f"Bootstrap signature does not exist: {signature}")

    with tempfile.TemporaryDirectory() as tmp:
        run(["gpgv", "--homedir", tmp, "--keyring", str(keyring), str(signature), str(bootstrap)])

    sources_names = {
        "etc/apt/sources.list.d/procursus.sources",
        "private/etc/apt/sources.list.d/procursus.sources",
    }
    keyring_name = "usr/share/keyrings/owngoal-procursus.gpg"
    status_name = "Library/dpkg/status"
    found = {}

    proc = subprocess.Popen(
        ["zstd", "-dc", str(bootstrap)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        with tarfile.open(fileobj=proc.stdout, mode="r|") as archive:
            for member in archive:
                name = normalize_member(member.name)
                if not member.isfile():
                    continue
                if name in sources_names or name in (keyring_name, status_name):
                    found[name] = archive.extractfile(member).read()
    finally:
        try:
            proc.stdout.close()
        except OSError:
            pass
        stderr = proc.stderr.read()
        returncode = proc.wait()
    if returncode:
        raise Fail(f"zstd failed on Bootstrap ({returncode}): {stderr.decode('utf-8', 'replace').strip()}")

    sources_name = next((name for name in sources_names if name in found), None)
    if sources_name is None:
        raise Fail("Bootstrap does not contain apt sources")
    if keyring_name not in found:
        raise Fail("Bootstrap does not contain the repository keyring")
    if status_name not in found:
        raise Fail("Bootstrap does not contain dpkg status")

    sources = parse_deb822(found[sources_name].decode("utf-8", "replace"))
    if len(sources) != 1:
        raise Fail(f"Bootstrap sources has {len(sources)} stanzas, expected 1")
    stanza = sources[0]
    expected = {
        "Types": "deb",
        "Suites": suite,
        "Components": component,
        "Signed-By": "/usr/share/keyrings/owngoal-procursus.gpg",
    }
    for key, value in expected.items():
        if stanza.get(key) != value:
            raise Fail(f"Bootstrap sources {key} is {stanza.get(key)!r}, expected {value!r}")
    if stanza.get("URIs", "").rstrip("/") != uri.rstrip("/"):
        raise Fail(
            f"Bootstrap sources URIs is {stanza.get('URIs')!r}, expected {uri!r}"
        )
    if found[keyring_name] != Path(keyring).read_bytes():
        raise Fail("Bootstrap public key does not match the repository keyring")

    repository_versions = {(r["Package"], r["Version"]) for r in records}
    members = parse_deb822(found[status_name].decode("utf-8", "replace"))
    for member in members:
        package = member.get("Package")
        version = member.get("Version")
        if (package, version) not in repository_versions:
            raise Fail(
                f"Bootstrap member {package}={version} is not in the repository"
            )
    return len(members)


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *unused):
        pass


def apt_test(repo, suite, component, arch, keyring, records, install_packages=()):
    if shutil.which("apt-get") is None:
        raise Fail("apt-get is required for the local verification test")
    candidates = [r for r in records if r["Architecture"] in (arch, "all")]
    if not candidates:
        raise Fail("no packages available for the apt verification test")
    arch_specific = [r for r in candidates if r["Architecture"] == arch]
    pool = arch_specific or candidates
    hello = [r for r in pool if r["Package"] == "hello"]
    sample = newest_record(hello) if hello else min(pool, key=lambda r: int(r["Size"]))

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        lists = root / "lists"
        cache = root / "cache"
        logdir = root / "log"
        for directory in (lists / "partial", cache / "archives" / "partial", logdir):
            directory.mkdir(parents=True)
        status = root / "status"
        status.touch()
        sources = root / "sources.list"
        download = root / "download"
        download.mkdir()

        handler = functools.partial(QuietHandler, directory=str(repo))
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        output = b""
        try:
            sources.write_text(
                f"deb [arch={arch} signed-by={keyring}] "
                f"http://127.0.0.1:{server.server_port} {suite} {component}\n"
            )
            options = [
                "-o", f"Dir::Etc::sourcelist={sources}",
                "-o", "Dir::Etc::sourceparts=-",
                "-o", "Dir::Etc::main=-",
                "-o", "Dir::Etc::parts=-",
                "-o", f"Dir::State::status={status}",
                "-o", f"Dir::State::lists={lists}",
                "-o", f"Dir::Cache={cache}",
                "-o", f"Dir::Cache::archives={cache / 'archives'}",
                "-o", f"Dir::Log={logdir}",
                "-o", f"APT::Architecture={arch}",
                "-o", f"APT::Sandbox::User={getpass.getuser()}",
                "-o", "APT::Update::Error-Mode=any",
                "-o", "Acquire::Languages=none",
                "-o", "Acquire::http::Proxy=false",
            ]
            update = run(["apt-get"] + options + ["update"], cwd=root, check=False)
            output += update.stdout + update.stderr
            if update.returncode:
                raise Fail(
                    "apt-get update failed:\n"
                    + (update.stdout + update.stderr).decode("utf-8", "replace")
                )
            if install_packages:
                simulated = run(["apt-get"] + options + ["--simulate", "--no-install-recommends", "install"] + list(install_packages), cwd=root, check=False)
                output += simulated.stdout + simulated.stderr
                if simulated.returncode:
                    raise Fail("apt dependency simulation failed:\n" + (simulated.stdout + simulated.stderr).decode("utf-8", "replace"))
            fetched = run(
                ["apt-get"] + options + [
                    "download", f"{sample['Package']}={sample['Version']}",
                ],
                cwd=download,
                check=False,
            )
            output += fetched.stdout + fetched.stderr
            if fetched.returncode:
                raise Fail(
                    "apt-get download failed:\n"
                    + (fetched.stdout + fetched.stderr).decode("utf-8", "replace")
                )
            debs = list(download.glob("*.deb"))
            if len(debs) != 1:
                raise Fail(f"apt-get download produced {len(debs)} files")
            if hash_file(debs[0]) != sample["SHA256"]:
                raise Fail("apt-get downloaded a package with an unexpected hash")
        finally:
            server.shutdown()
            server.server_close()
            worker.join()
    return output.decode("utf-8", "replace"), f"{sample['Package']}={sample['Version']}"


# ---------------------------------------------------------------------------
# Commands


def export_delivery(args):
    """Copy completed outputs into one platform's shared delivery directory."""
    source = Path(args.packages).resolve()
    output = Path(args.output).resolve()
    if not source.is_dir():
        raise Fail(f"package directory does not exist: {source}")
    if output == source or source in output.parents or output in source.parents:
        raise Fail("delivery output and package input must be separate directories")
    selected = set(args.recipe or [])
    packages = [(r, p) for r, p in discover_debs(source) if not selected or r in selected]
    missing = selected - {r for r, _ in packages}
    if missing or not packages:
        raise Fail("no packages for selection: " + ", ".join(sorted(missing)))
    copies = [(p, output / "packages" / r / p.name) for r, p in packages]
    if args.bootstrap:
        bootstrap = Path(args.bootstrap).resolve()
        for p in (bootstrap, Path(str(bootstrap) + ".asc")):
            if not p.is_file():
                raise Fail(f"missing signed Bootstrap input: {p}")
            copies.append((p, output / "bootstrap" / p.name))
    output.mkdir(parents=True, exist_ok=True)
    with publish_lock(output):
        planned = [(src, dst, hash_file(src)) for src, dst in copies]
        for src, dst, digest in planned:
            if dst.exists() and hash_file(dst) != digest and not args.replace:
                raise Fail(f"delivery conflict: {dst}; bump the version or explicitly use --replace")
        manifest_path = output / "delivery.json"
        manifest = load_state(manifest_path)
        records = manifest.get("files", {}) if manifest else {}
        for src, dst, digest in planned:
            if not dst.exists() or hash_file(dst) != digest:
                atomic_copy(src, dst)
            if hash_file(dst) != digest:
                raise Fail(f"delivery hash mismatch: {dst}")
            records[str(dst.relative_to(output))] = {
                "sha256": digest, "size": dst.stat().st_size, "revision": args.revision,
            }
        save_state(manifest_path, {"version": 1, "files": records})
    print(f"exported {len(packages)} DEBs; delivery hashes verified")


def update_repository(args):
    require_tools(["gpg"])
    packages_dir = Path(args.packages).resolve()
    repo = Path(args.repo).resolve()
    state_dir = Path(args.state_dir).resolve()
    suite = args.suite
    cfver = args.cfver
    component = args.component
    arch = args.arch
    pool_target = args.pool_target

    if not args.signing_key:
        raise Fail("set MEMO_PGP_SIGN_KEY or pass --signing-key")
    fingerprint = signing_fingerprint(args.signing_key)

    with publish_lock(state_dir):
        result = archive_packages(
            packages_dir,
            repo,
            component=component,
            pool_target=pool_target,
            cfver=cfver,
            replace=args.replace,
            prune=args.prune,
            dry_run=args.dry_run,
        )
        if result["total"] == 0:
            raise Fail(f"no .deb files found in {packages_dir}")

        manifest = pool_manifest(repo, component, pool_target, cfver, cache=result["cache"])
        config = state_config(repo, suite, cfver, component, arch, pool_target)
        state_file = state_path(state_dir, config)
        state = load_state(state_file)
        paths = index_paths(repo, suite, component, arch)
        required = [
            paths["release"],
            paths["release_gpg"],
            paths["inrelease"],
            paths["packages"],
            paths["packages_xz"],
            paths["packages_zst"],
            paths["binary_release"],
            paths["contents"],
            paths["contents_xz"],
            paths["contents_zst"],
        ]
        rebuild, reason = should_rebuild(
            state, manifest, fingerprint, required, force=args.force
        )
        if args.dry_run and (result["added"] or result["replaced"] or result["removed"]):
            rebuild = True
            reason = "dry-run would change packages"

        report = {
            "repo": str(repo),
            "suite": suite,
            "cfver": cfver,
            "component": component,
            "arch": arch,
            "pool_target": pool_target,
            "dry_run": args.dry_run,
            "packages": {
                "total": result["total"],
                "added": result["added"],
                "replaced": result["replaced"],
                "skipped": result["skipped"],
                "removed": [str(path) for path in result["removed"]],
            },
            "index": {
                "rebuilt": False,
                "would_rebuild": rebuild,
                "reason": reason,
            },
        }

        if not args.dry_run and rebuild:
            generate_index(
                repo,
                suite=suite,
                cfver=cfver,
                component=component,
                arch=arch,
                pool_target=pool_target,
                signing_key=args.signing_key,
                state_dir=state_dir,
                log=(lambda *_args, **_kwargs: None) if args.json else print,
            )
            save_state(
                state_file,
                {
                    "version": 1,
                    "signing_key": fingerprint,
                    "config": config,
                    "packages": manifest,
                    "generated": int(time.time()),
                },
            )
            report["index"]["rebuilt"] = True
    return report


def verify_repository(args):
    require_tools(["gpg", "gpgv", "zstd", "dpkg", "dpkg-deb", "apt-get"])
    repo = Path(args.repo).resolve()
    keyring = Path(args.keyring).resolve()
    bootstrap = Path(args.bootstrap).resolve()
    if not repo.is_dir():
        raise Fail(f"repository does not exist: {repo}")
    if not keyring.is_file():
        raise Fail(f"keyring does not exist: {keyring}")

    dist = repo / "dists" / args.suite
    release = verify_release_signature(dist, keyring)
    verify_release(dist, args.suite, args.component, args.arch, release)
    records = verify_packages(
        repo, args.suite, args.component, args.arch, args.pool_target, args.cfver
    )
    keyring_version = verify_keyring_package(repo, records, keyring)
    members = verify_bootstrap(
        bootstrap, keyring, repo, records, args.suite, args.component, args.arch, args.uri
    )
    apt_log, downloaded = apt_test(
        repo, args.suite, args.component, args.arch, keyring, records, args.check_install or ()
    )

    report = {
        "repo": str(repo),
        "suite": args.suite,
        "cfver": args.cfver,
        "arch": args.arch,
        "pool_target": args.pool_target,
        "packages": len(records),
        "keyring_version": keyring_version,
        "signing_fingerprints": keyring_fingerprints(keyring),
        "bootstrap_members": members,
        "apt_update": "passed over localhost HTTP with isolated apt state",
        "apt_download": downloaded,
        "apt_dependency_samples": args.check_install or [],
    }
    if args.report_dir:
        report_dir = Path(args.report_dir)
        report_dir.mkdir(parents=True, exist_ok=True)
        (report_dir / "apt-update.log").write_text(apt_log)
        (report_dir / "acceptance.json").write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n"
        )
    return report


# ---------------------------------------------------------------------------
# CLI


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    export = subparsers.add_parser("export", help="export completed packages to a shared delivery directory")
    export.add_argument("--packages", required=True)
    export.add_argument("--output", required=True)
    export.add_argument("--recipe", action="append", help="export only this recipe; repeat for multiple recipes")
    export.add_argument("--bootstrap", help="signed Bootstrap archive; its .asc must be present")
    export.add_argument("--revision", help="source commit used to build these outputs")
    export.add_argument("--replace", action="store_true", help="explicitly replace changed same-named outputs")

    update = subparsers.add_parser(
        "update", help="archive packages, rebuild indexes when needed, sign"
    )
    update.add_argument("--packages", required=True, help="build_dist target directory")
    update.add_argument("--repo", required=True, help="local APT repository root")
    update.add_argument("--state-dir", default="build_work/publish-state")
    update.add_argument("--suite", default=SUITE_DEFAULT)
    update.add_argument("--cfver", default=None)
    update.add_argument("--component", default=COMPONENT_DEFAULT)
    update.add_argument("--arch", default=ARCH_DEFAULT)
    update.add_argument("--pool-target", default=POOL_TARGET_DEFAULT)
    update.add_argument("--signing-key", default=os.environ.get("MEMO_PGP_SIGN_KEY"))
    update.add_argument(
        "--prune",
        action="store_true",
        help="remove pool packages that are absent from the build output",
    )
    update.add_argument(
        "--replace",
        action="store_true",
        help="replace a same-named package whose content changed",
    )
    update.add_argument("--force", action="store_true", help="rebuild indexes and signatures")
    update.add_argument("--dry-run", action="store_true")
    update.add_argument("--json", action="store_true")

    verify = subparsers.add_parser(
        "verify", help="verify indexes, signatures, keyring, Bootstrap and apt"
    )
    verify.add_argument("--repo", required=True)
    verify.add_argument("--keyring", default=os.environ.get("BOOTSTRAP_APT_KEYRING"))
    verify.add_argument("--bootstrap", required=True)
    verify.add_argument("--suite", default=SUITE_DEFAULT)
    verify.add_argument("--cfver", default=None)
    verify.add_argument("--component", default=COMPONENT_DEFAULT)
    verify.add_argument("--arch", default=ARCH_DEFAULT)
    verify.add_argument("--pool-target", default=POOL_TARGET_DEFAULT)
    verify.add_argument("--uri", default=os.environ.get("MEMO_REPO_URI", URI_DEFAULT))
    verify.add_argument("--report-dir", default=None)
    verify.add_argument("--json", action="store_true")
    verify.add_argument("--check-install", action="append", help="simulate dependency resolution for this package; repeat as needed")
    return parser


def validate_args(args):
    for name in ("suite", "cfver", "component", "arch", "pool_target"):
        value = getattr(args, name)
        if not value or not re.fullmatch(r"[A-Za-z0-9._-]+", value):
            raise Fail(f"invalid --{name.replace('_', '-')}: {value!r}")


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "export":
            export_delivery(args)
            return 0
        if args.cfver is None:
            args.cfver = args.suite
        validate_args(args)
        if args.command == "update":
            report = update_repository(args)
            if args.json:
                print(json.dumps(report, indent=2, sort_keys=True))
                return 0
            packages = report["packages"]
            print(
                "packages  total {}, added {}, replaced {}, skipped {}, removed {}".format(
                    packages["total"],
                    packages["added"],
                    packages["replaced"],
                    packages["skipped"],
                    len(packages["removed"]),
                )
            )
            if report["dry_run"]:
                state = "would rebuild" if report["index"]["would_rebuild"] else "up to date"
                print(f"index     {state} ({report['index']['reason']})")
            elif report["index"]["rebuilt"]:
                print("index     rebuilt")
            else:
                print(f"index     up to date ({report['index']['reason']})")
            return 0

        if not args.keyring:
            raise Fail("set BOOTSTRAP_APT_KEYRING or pass --keyring")
        report = verify_repository(args)
        if args.json:
            print(json.dumps(report, indent=2, sort_keys=True))
            return 0
        print("release   signature and hashes verified")
        print(f"packages  {report['packages']} records")
        print(f"keyring   procursus-keyring {report['keyring_version']}")
        print(f"bootstrap {report['bootstrap_members']} members, sources and keyring verified")
        print(f"apt       update and download passed ({report['apt_download']})")
        return 0
    except Fail as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    except subprocess.TimeoutExpired as error:
        print(f"error: timed out: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

