#!/usr/bin/env python3
"""Incremental mirror of a local tree into Proton Drive.

Why this exists: `proton drive items upload` has no incremental mode.
`--if-exists skip` is folder-granular -- once the destination folder exists the
whole tree is refused ("Nothing to upload"), so an interrupted upload can never
resume. `--if-exists replace` re-uploads every byte on every run. Neither is
usable for a repeated backup of a large tree, so this script does the change
detection itself:

  1. walk the tree once, hashing each directory bottom-up
     (files: name/size/mtime_ns, subdirs: name/child digest);
  2. split the tree into disjoint *units* -- a directory subtree, or a single
     file when a directory is larger than --unit-size and has no subdirs left
     to split on (bounds both the number of CLI calls and the cost of retrying
     one changed file);
  3. upload only the units whose digest differs from the last successful run,
     with `--if-exists replace`.

Deliberate limitations:
  * no remote pruning -- a file deleted locally stays in Drive. Remove it with
    `proton drive items delete <remote path> --yes`;
  * mtime is trusted as a change signal (a same-size file whose mtime is
    preserved will be missed; use --full to force a complete re-upload);
  * symlinks are skipped, not followed.

State lives in ~/.local/state/proton-drive-backup/state.json.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import stat
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_ROOT = "/data/proton-drive"
DEFAULT_REMOTE = "/Backups/proton-drive"
DEFAULT_STATE = Path.home() / ".local/state/proton-drive-backup/state.json"
GIB = 1024**3

# Skipped by default. `apps` holds live SQLite databases (with -wal/-shm) and
# regenerable thumbnails -- copying a WAL trio mid-write is how these corrupt,
# so it is snapshotted properly instead. `secrets` holds recovery codes for the
# very account being uploaded to (plus Google OAuth client secrets): storing
# them inside that account is a circular dependency, so it is opt-in.
DEFAULT_EXCLUDES = ["apps", "secrets", "node_modules", ".cache", ".Trash-*", ".Trash-1000"]


def log(msg: str, *, quiet: bool = False) -> None:
    if not quiet:
        print(msg, file=sys.stderr, flush=True)


def human(n: float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if abs(n) < 1024 or unit == "TiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024
    return f"{n:.1f} TiB"


def run_proton(args: list[str], timeout: int = 3600) -> tuple[int, str, str]:
    cmd = ["proton", "--no-input", "--no-log", *args]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 124, "", f"timed out after {timeout}s: {' '.join(cmd)}"
    except FileNotFoundError:
        return 127, "", "proton: command not found"


# --------------------------------------------------------------------------
# tree scan
# --------------------------------------------------------------------------


class Tree:
    def __init__(self, root: Path, excludes: list[str]) -> None:
        self.root = root
        self.excludes = set(excludes)
        self.children: dict[str, list[str]] = {}
        self.size: dict[str, int] = {}
        self.digest: dict[str, bytes] = {}
        self.files: dict[str, list[str]] = {}
        self.nfiles: dict[str, int] = {}
        self.excluded: list[str] = []
        self.symlinks: list[str] = []
        self.errors: list[str] = []
        self._excluded_names = set()

    def _skip_dir(self, name: str) -> bool:
        import fnmatch

        if name in self._excluded_names:
            return True
        return any(fnmatch.fnmatch(name, pat) for pat in self.excludes)

    def scan(self, path: str) -> tuple[int, bytes]:
        total = 0
        nfiles = 0
        entries: list[bytes] = []
        direct_files: list[str] = []
        subdirs: list[str] = []
        try:
            it = os.scandir(path)
        except OSError as exc:
            self.errors.append(f"{path}: {exc}")
            self.children[path] = []
            self.size[path] = 0
            self.digest[path] = hashlib.sha256(b"").digest()
            self.nfiles[path] = 0
            self.files[path] = []
            return 0, self.digest[path]
        with it:
            for entry in it:
                try:
                    st = entry.stat(follow_symlinks=False)
                except OSError as exc:
                    self.errors.append(f"{entry.path}: {exc}")
                    continue
                mode = st.st_mode
                name = entry.name.encode("utf-8", "surrogateescape")
                if stat.S_ISLNK(mode):
                    self.symlinks.append(entry.path)
                    continue
                if stat.S_ISDIR(mode):
                    if self._skip_dir(entry.name):
                        self.excluded.append(entry.path)
                        continue
                    csize, cdig = self.scan(entry.path)
                    total += csize
                    nfiles += self.nfiles[entry.path]
                    subdirs.append(entry.path)
                    entries.append(b"D\x00" + name + b"\x00" + cdig)
                elif stat.S_ISREG(mode):
                    total += st.st_size
                    nfiles += 1
                    direct_files.append(entry.path)
                    entries.append(
                        b"F\x00"
                        + name
                        + b"\x00"
                        + str(st.st_size).encode()
                        + b"\x00"
                        + str(st.st_mtime_ns).encode()
                    )
        entries.sort()
        h = hashlib.sha256()
        for chunk in entries:
            h.update(chunk)
        self.children[path] = subdirs
        self.size[path] = total
        self.nfiles[path] = nfiles
        self.files[path] = direct_files
        self.digest[path] = h.digest()
        return total, h.digest()


# --------------------------------------------------------------------------
# units
# --------------------------------------------------------------------------


class Unit:
    __slots__ = ("path", "kind", "size", "files", "digest", "rel")

    def __init__(self, path: str, kind: str, size: int, files: int, digest: bytes, root: Path):
        self.path = path
        self.kind = kind  # "dir" | "file"
        self.size = size
        self.files = files
        self.digest = digest
        self.rel = os.path.relpath(path, root)


def build_units(tree: Tree, root: Path, threshold: int) -> list[Unit]:
    units: list[Unit] = []

    def rec(path: str) -> None:
        subs = tree.children.get(path, [])
        if tree.size[path] <= threshold or not subs:
            if tree.size[path] <= threshold:
                units.append(
                    Unit(path, "dir", tree.size[path], tree.nfiles[path], tree.digest[path], root)
                )
            else:
                # oversized flat directory: one unit per file so a single
                # changed wav does not drag the whole directory back up
                for f in tree.files[path]:
                    try:
                        st = os.stat(f, follow_symlinks=False)
                    except OSError as exc:
                        tree.errors.append(f"{f}: {exc}")
                        continue
                    dig = hashlib.sha256(
                        b"F\x00"
                        + os.path.basename(f).encode("utf-8", "surrogateescape")
                        + b"\x00"
                        + str(st.st_size).encode()
                        + b"\x00"
                        + str(st.st_mtime_ns).encode()
                    ).digest()
                    units.append(Unit(f, "file", st.st_size, 1, dig, root))
            return
        for s in subs:
            rec(s)

    rec(str(root))
    units.sort(key=lambda u: u.rel)
    return units


# --------------------------------------------------------------------------
# refern snapshot
# --------------------------------------------------------------------------


def refern_snapshot(root: Path, keep: int, quiet: bool) -> Path | None:
    db = root / "apps/refern/refern-db.sqlite"
    if not db.exists():
        log("refern: database not found, skipping snapshot", quiet=quiet)
        return None
    outdir = root / "backups/refern"
    outdir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%d")
    dest = outdir / f"refern-db-{stamp}.sqlite"
    tmp = outdir / f".{dest.name}.tmp"
    try:
        if tmp.exists():
            tmp.unlink()
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        try:
            con.execute("VACUUM INTO ?", (str(tmp),))
        finally:
            con.close()
        os.replace(tmp, dest)
    except Exception as exc:  # noqa: BLE001 - a failed snapshot must not stop the backup
        log(f"refern: snapshot FAILED ({exc})", quiet=quiet)
        if tmp.exists():
            tmp.unlink()
        return None
    snaps = sorted(outdir.glob("refern-db-*.sqlite"))
    for old in snaps[:-keep]:
        old.unlink()
        log(f"refern: pruned {old.name}", quiet=quiet)
    log(f"refern: snapshot {dest.name} ({human(dest.stat().st_size)})", quiet=quiet)
    return dest


# --------------------------------------------------------------------------
# remote helpers
# --------------------------------------------------------------------------


def remote_path(remote_root: str, rel: str) -> str:
    return remote_root.rstrip("/") + "/" + rel.replace(os.sep, "/")


def ensure_folder(path: str, known: set[str], covered: list[str], quiet: bool) -> bool:
    """Make sure `path` exists. `covered` collects the paths this run created --
    `items create` builds every missing ancestor, so one deep create covers its
    whole parent chain (the reverse is NOT true: creating a folder does not
    create anything inside it)."""
    if path in known:
        return True
    rc, out, err = run_proton(["drive", "items", "create", path])
    text = (out + err).lower()
    if rc == 0:
        known.add(path)
        covered.append(path)
        return True
    if "already has a folder" in text:
        known.add(path)
        return True
    log(f"ERROR creating folder {path}: {(err or out).strip()}", quiet=quiet)
    return False


def ensure_parents(paths: list[str], remote_root: str, quiet: bool) -> bool:
    known: set[str] = set()
    covered: list[str] = []
    if not ensure_folder(remote_root, known, covered, quiet):
        raise SystemExit(f"cannot create remote root {remote_root}")
    # deepest first, so each create also builds the parents above it
    wanted = sorted({os.path.dirname(p) for p in paths}, key=lambda p: -p.count("/"))
    ok = True
    for w in wanted:
        if any(c == w or c.startswith(w + "/") for c in covered):
            continue
        if not ensure_folder(w, known, covered, quiet):
            ok = False
    return ok


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Incrementally mirror a local tree into Proton Drive.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("--root", default=DEFAULT_ROOT, help=f"local tree (default {DEFAULT_ROOT})")
    ap.add_argument("--remote", default=DEFAULT_REMOTE, help=f"remote folder (default {DEFAULT_REMOTE})")
    ap.add_argument("--state", default=str(DEFAULT_STATE), help="state file")
    ap.add_argument(
        "--unit-size",
        default="2G",
        help="largest directory subtree uploaded as one unit (default 2G; larger dirs are split, "
        "and a flat dir above the limit uploads per file)",
    )
    ap.add_argument("--jobs", type=int, default=3, help="parallel uploads (default 3)")
    ap.add_argument("--exclude", action="append", default=[], help="extra name/glob to skip (repeatable)")
    ap.add_argument("--include-secrets", action="store_true", help="also upload ./secrets (off by default)")
    ap.add_argument("--only", action="append", default=[], help="only these top-level names (repeatable)")
    ap.add_argument("--full", action="store_true", help="ignore state, re-upload every unit")
    ap.add_argument("-n", "--dry-run", action="store_true", help="report what would be uploaded")
    ap.add_argument("--no-refern-snapshot", action="store_true", help="skip the refern VACUUM INTO snapshot")
    ap.add_argument("--refern-keep", type=int, default=3, help="refern snapshots to keep (default 3)")
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"error: {root} is not a directory", file=sys.stderr)
        return 2

    threshold = parse_size(args.unit_size)
    excludes = [e for e in DEFAULT_EXCLUDES if not (args.include_secrets and e == "secrets")]
    excludes += args.exclude

    state_path = Path(args.state).expanduser()
    state_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = state_path.with_suffix(".lock")
    lock_fh = open(lock_path, "w")
    try:
        import fcntl

        fcntl.flock(lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("error: another backup is already running", file=sys.stderr)
        return 3

    started = time.time()
    log(f"proton-drive-backup: {root} -> {args.remote}  (unit {args.unit_size}, jobs {args.jobs})", quiet=args.quiet)

    if not args.no_refern_snapshot:
        refern_snapshot(root, args.refern_keep, args.quiet)

    tree = Tree(root, excludes)
    total, _ = tree.scan(str(root))
    units = build_units(tree, root, threshold)

    if args.only:
        keep = set(args.only)
        units = [u for u in units if u.rel.split(os.sep)[0] in keep]
        total = sum(u.size for u in units)

    state: dict = {"version": 1, "root": str(root), "remote": args.remote, "units": {}}
    if state_path.exists():
        try:
            loaded = json.loads(state_path.read_text())
            if loaded.get("root") == str(root) and loaded.get("remote") == args.remote:
                state = loaded
            elif loaded.get("root") != str(root):
                log(
                    f"warning: state belongs to {loaded.get('root')} (remote {loaded.get('remote')}); "
                    "starting fresh",
                    quiet=args.quiet,
                )
        except (json.JSONDecodeError, OSError) as exc:
            log(f"warning: unreadable state ({exc}); starting fresh", quiet=args.quiet)

    known = state["units"]
    planned: list[Unit] = []
    for u in units:
        prev = known.get(u.rel)
        if args.full or not prev or prev.get("sig") != u.digest.hex() or not prev.get("at"):
            planned.append(u)

    log(
        f"scan: {len(units)} units, {human(total)} local; "
        f"{len(units) - len(planned)} unchanged, {len(planned)} to upload "
        f"({human(sum(u.size for u in planned))})",
        quiet=args.quiet,
    )
    for p in tree.excluded:
        log(f"  excluded {os.path.relpath(p, root)}", quiet=args.quiet)
    if tree.symlinks:
        log(f"  skipped {len(tree.symlinks)} symlinks", quiet=args.quiet)
    for e in tree.errors[:10]:
        log(f"  scan error {e}", quiet=args.quiet)

    if args.dry_run:
        for u in planned:
            log(f"  would upload {u.kind:4s} {u.rel}  ({human(u.size)})", quiet=False)
        log("dry run: nothing uploaded", quiet=args.quiet)
        return 0

    if not planned:
        log(f"up to date in {time.time() - started:.1f}s", quiet=args.quiet)
        return 0

    parents = [remote_path(args.remote, os.path.relpath(u.path, root)) for u in planned]
    if not ensure_parents(parents, args.remote, args.quiet):
        log("warning: some destination folders could not be created; those units will fail", quiet=args.quiet)

    failed: list[tuple[Unit, str]] = []
    done = 0
    sent = 0
    width = len(str(len(planned)))

    def work(u: Unit) -> tuple[Unit, bool, str]:
        parent_rel = os.path.dirname(u.rel)
        dest = args.remote.rstrip("/")
        if parent_rel:
            dest += "/" + parent_rel.replace(os.sep, "/")
        cmd = ["drive", "items", "upload", "--if-exists", "replace"]
        if u.kind == "dir":
            cmd.append("--recursive")
        cmd += [u.path, dest]
        rc, out, err = run_proton(cmd)
        return u, rc == 0, (err or out).strip()

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        futures = {pool.submit(work, u): u for u in planned}
        for fut in as_completed(futures):
            unit, ok, msg = fut.result()
            done += 1
            if ok:
                sent += unit.size
                known[unit.rel] = {
                    "kind": unit.kind,
                    "sig": unit.digest.hex(),
                    "bytes": unit.size,
                    "files": unit.files,
                    "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                }
                log(
                    f"[{done:{width}d}/{len(planned)}] ok   {unit.kind:4s} {unit.rel}  ({human(unit.size)})",
                    quiet=args.quiet,
                )
            else:
                failed.append((unit, msg))
                log(f"[{done:{width}d}/{len(planned)}] FAIL {unit.kind:4s} {unit.rel}: {msg}", quiet=args.quiet)
            # persist progress so an interrupted run keeps what it finished
            if done % 10 == 0 or done == len(planned):
                state_path.write_text(json.dumps(state, indent=1))

    state_path.write_text(json.dumps(state, indent=1))
    elapsed = time.time() - started
    rate = human(sent / elapsed) + "/s" if elapsed > 0 and sent else "-"
    log(
        f"done: {len(planned) - len(failed)} uploaded ({human(sent)}, {rate}), "
        f"{len(failed)} failed, {elapsed / 60:.1f} min",
        quiet=args.quiet,
    )
    if failed:
        log("failures:", quiet=args.quiet)
        for unit, msg in failed[:20]:
            log(f"  {unit.rel}: {msg}", quiet=args.quiet)
        return 1
    return 0


def parse_size(text: str) -> int:
    text = text.strip().lower()
    mult = 1
    for suffix, m in (("kib", 1024), ("kb", 1000), ("mib", 1024**2), ("mb", 1000**2),
                      ("gib", GIB), ("gb", 1000**3), ("k", 1024), ("m", 1024**2), ("g", GIB)):
        if text.endswith(suffix):
            text = text[: -len(suffix)]
            mult = m
            break
    return int(float(text) * mult)


if __name__ == "__main__":
    sys.exit(main())
