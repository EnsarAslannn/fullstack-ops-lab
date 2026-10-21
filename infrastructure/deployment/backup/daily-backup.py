#!/usr/bin/env python3
"""Local deployment PostgreSQL backups; no Compose lifecycle or restore actions."""

import argparse
from contextlib import contextmanager
from datetime import date, datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import uuid
from zoneinfo import ZoneInfo


OWNER = "fullstackops-deploy-lab-daily-v1"
SOURCE = "fullstackops-deploy-lab-postgres-1"
VOLUME = "fullstackops-deploy-lab-postgres"
DEFAULT_ROOT = Path("/var/lib/fullstackops-deploy-lab-backup")
DAY_PATTERN = re.compile(r"\d{4}-\d{2}-\d{2}")


class BackupError(Exception):
    def __init__(self, stage, command_exit=None):
        self.stage = stage
        self.command_exit = command_exit


def istanbul_now():
    return datetime.now(ZoneInfo("Europe/Istanbul"))


def utc_text(value):
    return value.astimezone(timezone.utc).isoformat()


def private_path(path, directory=False):
    info = path.lstat()
    expected = stat.S_ISDIR if directory else stat.S_ISREG
    if not expected(info.st_mode) or path.is_symlink():
        raise BackupError("unsafe-path")
    if not directory and info.st_nlink != 1:
        raise BackupError("unsafe-hardlink")
    if os.name != "nt":
        if info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != (0o700 if directory else 0o600):
            raise BackupError("unsafe-permissions")


def prepare_root(root):
    if not root.is_absolute() or "backups-private" in root.parts:
        raise BackupError("unsafe-root")
    for parent in (root, *root.parents):
        if parent.is_symlink() or (parent / ".git").exists():
            raise BackupError("unsafe-root")
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    private_path(root, directory=True)
    marker = root / ".owner"
    if not marker.exists():
        if any(root.iterdir()):
            raise BackupError("unowned-root")
        with marker.open("x", encoding="utf-8") as handle:
            handle.write(OWNER)
        marker.chmod(0o600)
    private_path(marker)
    if marker.read_text(encoding="utf-8") != OWNER:
        raise BackupError("unowned-root")


@contextmanager
def backup_lock(root):
    path = root / ".lock"
    fd = os.open(path, os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0), 0o600)
    acquired = False
    try:
        private_path(path)
        if os.fstat(fd).st_size == 0:
            os.write(fd, b"0")
        os.lseek(fd, 0, os.SEEK_SET)
        try:
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            acquired = True
        except OSError:
            raise BackupError("busy", 75) from None
        yield
    finally:
        if acquired:
            if os.name == "nt":
                import msvcrt
                os.lseek(fd, 0, os.SEEK_SET)
                msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def atomic_json(path, value):
    temporary = path.with_name(".state-" + uuid.uuid4().hex)
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    temporary.replace(path)


def digest(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


class DockerSource:
    def command(self, stage, *args):
        try:
            result = subprocess.run(["docker", "--host", "unix:///var/run/docker.sock", *args],
                                    capture_output=True, timeout=240)
        except subprocess.TimeoutExpired:
            raise BackupError(stage, 124) from None
        except OSError:
            raise BackupError(stage, 127) from None
        if result.returncode or result.stderr:
            raise BackupError(stage, result.returncode) from None
        return result.stdout

    def inspect(self):
        template = ('{"id":{{json .Id}},"image":{{json .Image}},'
                    '"project":{{json (index .Config.Labels "com.docker.compose.project")}},'
                    '"service":{{json (index .Config.Labels "com.docker.compose.service")}},'
                    '"state":{{json .State.Status}},"health":{{json .State.Health.Status}},'
                    '"ports":{{json .HostConfig.PortBindings}},"mounts":{{json .Mounts}}}')
        info = json.loads(self.command("source-inspect", "inspect", "--format", template, SOURCE))
        if (info["project"] != "fullstackops-deploy-lab" or info["service"] != "postgres"
                or info["state"] != "running" or info["health"] != "healthy" or info["ports"]
                or not re.fullmatch(r"[a-f0-9]{64}", info["id"])
                or not re.fullmatch(r"sha256:[a-f0-9]{64}", info["image"])):
            raise BackupError("source-identity")
        mounts = info["mounts"]
        if (len(mounts) != 1 or mounts[0]["Type"] != "volume" or mounts[0]["Name"] != VOLUME
                or mounts[0]["Destination"] != "/var/lib/postgresql" or not mounts[0]["RW"]):
            raise BackupError("source-volume")
        return info

    def export(self, destination):
        source = self.inspect()
        container = source["id"]
        versions = [self.command("tool-version", "exec", container, tool, "--version").decode().strip()
                    for tool in ("pg_dump", "pg_restore")]
        if any(not re.search(r"\b18\.\d+\b", version) for version in versions):
            raise BackupError("tool-major-version")
        server = self.command("server-version", "exec", container, "sh", "-c",
                              'exec psql --host=/var/run/postgresql --no-password -XAt '
                              '-v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" '
                              '-c "SHOW server_version"').decode().strip()
        match = re.match(r"18\.\d+\b", server)
        if not match or any(re.search(r"\b18\.\d+\b", version).group() != match.group() for version in versions):
            raise BackupError("server-tool-version")
        remote = "/tmp/fullstackops-daily-" + uuid.uuid4().hex
        self.command("temporary-directory", "exec", container, "mkdir", "-m", "700", remote)
        try:
            self.command("dump", "exec", container, "sh", "-c",
                         'umask 077; exec timeout 180 pg_dump --format=custom --no-privileges '
                         '--no-password --host=/var/run/postgresql --lock-wait-timeout=5s --file="$1/database.pgdump" '
                         '-U "$POSTGRES_USER" -d "$POSTGRES_DB"', "sh", remote)
            remote_hash = self.command("container-checksum", "exec", container, "sha256sum",
                                       remote + "/database.pgdump").decode().split()[0]
            self.command("copy", "cp", container + ":" + remote + "/database.pgdump", str(destination))
            destination.chmod(0o600)
            private_path(destination)
            if destination.stat().st_size == 0 or digest(destination) != remote_hash:
                raise BackupError("copy-checksum")
            listing = self.command("archive-check", "exec", container, "pg_restore", "--list",
                                   remote + "/database.pgdump")
            if not all(entry in listing for entry in (b"TABLE DATA public tasks ",
                       b"TABLE DATA public __EFMigrationsHistory ", b"SEQUENCE SET public tasks_id_seq ")):
                raise BackupError("archive-contents")
            if self.inspect()["id"] != container:
                raise BackupError("source-changed")
        finally:
            self.command("temporary-cleanup", "exec", container, "sh", "-c",
                         'rm -f -- "$1/database.pgdump" && rmdir -- "$1"', "sh", remote)
        return {"source_container_id": container, "source_image_id": source["image"],
                "source_volume": VOLUME, "tools": versions, "server_version": match.group()}


def checked_set(path):
    private_path(path, directory=True)
    private_path(path / "manifest.json")
    metadata = json.loads((path / "manifest.json").read_text(encoding="utf-8"))
    if (metadata["owner"] != OWNER or metadata["day"] != path.name
            or date.fromisoformat(path.name).isoformat() != path.name
            or set(item.name for item in path.iterdir()) != {"manifest.json", "database.pgdump"}):
        raise BackupError("set-ownership")
    archive = path / "database.pgdump"
    private_path(archive)
    if archive.stat().st_size != metadata["bytes"] or digest(archive) != metadata["sha256"]:
        raise BackupError("set-checksum")
    return metadata


def retain_seven(root, today):
    owned = []
    for path in sorted(root.iterdir()):
        if not DAY_PATTERN.fullmatch(path.name):
            continue
        if path.is_symlink():
            raise BackupError("retention-symlink")
        if not path.is_dir() or not (path / "manifest.json").exists():
            continue
        private_path(path / "manifest.json")
        metadata = json.loads((path / "manifest.json").read_text(encoding="utf-8"))
        if metadata.get("owner") != OWNER:
            continue
        checked_set(path)
        if path.name > today:
            raise BackupError("clock-before-existing-set")
        owned.append(path)
    # Validate every candidate before deleting anything; never recurse into unknown files.
    for path in owned[:-7]:
        checked_set(path)
        (path / "database.pgdump").unlink()
        (path / "manifest.json").unlink()
        path.rmdir()
    return len(owned[:-7])


def run_backup(root, clock=istanbul_now):
    os.umask(0o077)
    try:
        prepare_root(root)
        with backup_lock(root):
            try:
                now = clock()
                today = now.date().isoformat()
                target = root / today
                if target.exists():
                    metadata = checked_set(target)
                    result = "already-complete"
                else:
                    working = root / (".partial-" + uuid.uuid4().hex)
                    working.mkdir(mode=0o700)
                    archive = working / "database.pgdump"
                    source = DockerSource().export(archive)
                    metadata = {"owner": OWNER, "day": today, "timezone": "Europe/Istanbul",
                                "completed_utc": utc_text(clock()), "bytes": archive.stat().st_size,
                                "sha256": digest(archive), **source}
                    atomic_json(working / "manifest.json", metadata)
                    working.rename(target)
                    checked_set(target)
                    result = "completed"
                # Repair a pointer interrupted after promotion, without refreshing its timestamp.
                atomic_json(root / "last-success.json", metadata)
                removed = retain_seven(root, today)
                atomic_json(root / "last-attempt.json", {"checked_utc": utc_text(clock()),
                            "exit_code": 0, "result": result, "removed_sets": removed})
                print("backup result=" + result + " exit=0 removed_sets=" + str(removed))
                return 0
            except Exception as error:
                stage = error.stage if isinstance(error, BackupError) else "local-io-or-metadata"
                code = error.command_exit if isinstance(error, BackupError) else None
                atomic_json(root / "last-attempt.json", {"checked_utc": utc_text(clock()),
                            "exit_code": 1, "result": "failed", "stage": stage, "command_exit": code})
                print("backup result=failed exit=1 stage=" + stage)
                return 1
    except Exception as error:
        busy = isinstance(error, BackupError) and error.stage == "busy"
        print("backup result=" + ("busy exit=75" if busy else "preflight-failed exit=1"))
        return 75 if busy else 1


def show_status(root, clock=istanbul_now):
    try:
        private_path(root, directory=True)
        for name in ("last-success.json", "last-attempt.json"):
            private_path(root / name)
        success = json.loads((root / "last-success.json").read_text(encoding="utf-8"))
        attempt = json.loads((root / "last-attempt.json").read_text(encoding="utf-8"))
        if not DAY_PATTERN.fullmatch(success["day"]):
            raise BackupError("status-day")
        metadata = checked_set(root / success["day"])
        if metadata != success:
            raise BackupError("status-pointer")
        age = (clock() - datetime.fromisoformat(success["completed_utc"])).total_seconds()
        print("last_success_utc=" + success["completed_utc"])
        print("last_success_age_hours=" + str(round(age / 3600, 2)))
        print("last_attempt_exit=" + str(int(attempt["exit_code"])))
        print("windows_copy=manual-not-verified-by-this-job")
        return 0 if 0 <= age < 86400 and attempt["exit_code"] == 0 else 2
    except Exception:
        print("backup status=missing-or-invalid exit=2")
        return 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--status", action="store_true", help="Read-only status; exit 2 if stale or failed")
    options = parser.parse_args()
    raise SystemExit(show_status(options.root) if options.status else run_backup(options.root))
