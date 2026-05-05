#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from collections import defaultdict, deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_PROP_FILES = (SCRIPT_DIR / ".." / "proprietary-files.txt").resolve()
DEFAULT_LOCAL_ALL_FILES = (SCRIPT_DIR / "all_files.txt").resolve()
AUTO_HEADER = "# Auto-added by resolve-missing-blobs"
SUPPRESSED_NEEDED = {
    "android.hardware.gnss-V1-ndk_platform.so",
}
SCAN_PREFIXES = ("vendor/", "system/", "system_ext/", "product/")
ELF_PATH_HINTS = ("/bin/", "/lib/", "/lib64/")
PARTITION_GROUPS = {
    "vendor": "vendor",
    "odm": "vendor",
    "system": "system",
    "system_ext": "system",
    "product": "system",
}


def parse_args():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=(
            "Resolve missing blob-backed ELF modules offline by scanning DT_NEEDED\n"
            "dependencies from an extracted stock dump.\n\n"
            "Run a dry run first to inspect proposed additions, then re-run with\n"
            "--apply to prepend a generated block into proprietary-files.txt."
        ),
        epilog=(
            "Examples:\n"
            "  Dry run with defaults:\n"
            "    python3 resolve-missing-blobs.py --dump-root /path/to/dump\n\n"
            "  Apply additions into proprietary-files.txt:\n"
            "    python3 resolve-missing-blobs.py \\\n"
            "      --dump-root /path/to/dump --apply\n\n"
            "  Skip source-built outputs listed in an exclude file:\n"
            "    python3 resolve-missing-blobs.py \\\n"
            "      --dump-root /path/to/dump --exclude exclude-list.txt\n\n"
            "  Suppress paths already provided by source modules:\n"
            "    python3 resolve-missing-blobs.py \\\n"
            "      --dump-root /path/to/dump --module-info /path/to/module-info.json\n\n"
            "  Emit machine-readable JSON for scripting:\n"
            "    python3 resolve-missing-blobs.py \\\n"
            "      --dump-root /path/to/dump --json\n\n"
            "  JSON without progress logs on stderr:\n"
            "    python3 resolve-missing-blobs.py \\\n"
            "      --dump-root /path/to/dump --json --quiet\n\n"
            "  Tune scan parallelism:\n"
            "    python3 resolve-missing-blobs.py \\\n"
            "      --dump-root /path/to/dump --jobs 16\n\n"
            "  Allow proposing system-side providers too:\n"
            "    python3 resolve-missing-blobs.py \\\n"
            "      --dump-root /path/to/dump --include-system"
        ),
    )
    parser.add_argument(
        "--dump-root",
        default="",
        help=(
            "Path to the extracted stock dump root. Required."
        ),
    )
    parser.add_argument(
        "--proprietary",
        default=str(DEFAULT_PROP_FILES),
        help=(
            "Path to proprietary-files.txt to read from in dry-run mode and "
            "prepend to when --apply is used."
        ),
    )
    parser.add_argument(
        "--all-files",
        default="",
        help=(
            "Override the all_files.txt source. By default the script uses "
            "<dump-root>/all_files.txt and falls back to dev/all_files.txt."
        ),
    )
    parser.add_argument(
        "--exclude",
        default="",
        help=(
            "Path to a proprietary-style exclude list. Excluded providers are "
            "not proposed as blob additions, but their dependencies are still "
            "traversed if present in the dump."
        ),
    )
    parser.add_argument(
        "--module-info",
        default="",
        help=(
            "Path to Soong module-info.json. Providers whose installed paths "
            "already come from source modules are not proposed as blob "
            "additions, but their dependencies are still traversed."
        ),
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help=(
            "Prepend a generated '# Auto-added by resolve-missing-blobs' block "
            "to the target proprietary file."
        ),
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help=(
            "Write the final result as JSON to stdout. Progress logs still go "
            "to stderr unless --quiet is used."
        ),
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=default_jobs(),
        help=(
            "Number of concurrent readelf scan workers. Higher values increase "
            "I/O and subprocess parallelism."
        ),
    )
    parser.add_argument(
        "--max-depth",
        type=int,
        default=None,
        help="Limit transitive dependency traversal depth.",
    )
    parser.add_argument(
        "--include-system",
        action="store_true",
        help=(
            "Allow proposing system/system_ext/product providers. By default "
            "the resolver only proposes vendor-side additions."
        ),
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress progress logs on stderr and only emit the final result.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Compatibility alias. Verbose progress logging is already the default.",
    )
    if len(sys.argv) == 1:
        parser.print_help()
        raise SystemExit(0)
    return parser.parse_args()


def default_jobs():
    cpu_count = os.cpu_count() or 1
    return min(32, max(4, cpu_count * 4))


def log(enabled: bool, message: str):
    if enabled:
        print(message, file=sys.stderr, flush=True)


def read_all_paths(path: Path):
    paths = []
    with path.open("r", encoding="utf-8", errors="ignore") as handle:
        for raw in handle:
            line = raw.strip()
            if line and not line.startswith("#") and line != "all_files.txt":
                paths.append(line)
    return paths


def parse_proprietary_entry(raw: str):
    line = raw.rstrip("\n")
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return None

    is_named_dependency = stripped.startswith("-")
    if is_named_dependency:
        stripped = stripped[1:].strip()

    flags = []
    if ";" in stripped:
        stripped, flag_suffix = stripped.split(";", 1)
        stripped = stripped.strip()
        flags = [flag.strip() for flag in flag_suffix.split("|") if flag.strip()]

    source = None
    dest = stripped
    if ":" in stripped:
        source, dest = stripped.split(":", 1)
        source = source.strip() or None
        dest = dest.strip() or source

    return {
        "raw_line": line,
        "source": source,
        "dest": dest,
        "is_named_dependency": is_named_dependency,
        "flags": flags,
        "aliases": alias_paths(dest),
    }


def alias_paths(path: str):
    aliases = [path]
    prefixes = [
        ("system/", "system/system/"),
        ("system/system/", "system/"),
        ("system_ext/", "system/system_ext/"),
        ("system/system_ext/", "system_ext/"),
        ("product/", "system/product/"),
        ("system/product/", "product/"),
    ]
    for left, right in prefixes:
        if path.startswith(left):
            alt = right + path[len(left) :]
            if alt not in aliases:
                aliases.append(alt)
    return aliases


def load_parsed_entries(path: Path):
    entries = []
    with path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            entry = parse_proprietary_entry(raw)
            if entry is not None:
                entries.append(entry)
    return entries


def load_tracked_entries(path: Path):
    tracked = set()
    roots = []
    entries = load_parsed_entries(path)
    for entry in entries:
        tracked.update(entry["aliases"])
        roots.append(entry["dest"])
    return tracked, roots, entries


def load_excluded_entries(path: Path):
    excluded = set()
    entries = load_parsed_entries(path)
    for entry in entries:
        excluded.update(entry["aliases"])
    return excluded, entries


def load_module_info(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)

    provided = defaultdict(set)
    for module_key, module in payload.items():
        module_name = module.get("module_name") or module_key
        for installed_path in module.get("installed", []):
            if not installed_path:
                continue
            normalized = normalize_installed_path(installed_path)
            if normalized is None:
                continue
            for alias in alias_paths(normalized):
                provided[alias].add(module_name)

    return {key: sorted(values) for key, values in sorted(provided.items())}


def normalize_installed_path(installed_path: str):
    partitions = ("vendor/", "odm/", "system/", "system_ext/", "product/")
    normalized = installed_path.replace("\\", "/")
    for partition in partitions:
        needle = "/" + partition
        if normalized.startswith(needle):
            return normalized[1:]
        index = normalized.find(needle)
        if index != -1:
            return normalized[index + 1 :]
    if normalized.startswith(partitions):
        return normalized
    return None


def choose_all_files_path(dump_root: Path, explicit: str):
    if explicit:
        path = Path(explicit).expanduser().resolve()
        if not path.is_file():
            raise SystemExit(f"all-files not found: {path}")
        return path

    dump_all_files = (dump_root / "all_files.txt").resolve()
    if dump_all_files.is_file():
        return dump_all_files
    if DEFAULT_LOCAL_ALL_FILES.is_file():
        return DEFAULT_LOCAL_ALL_FILES
    raise SystemExit("Could not find all_files.txt. Use --all-files.")


def should_scan_path(rel_path: str):
    if not rel_path.startswith(SCAN_PREFIXES):
        return False
    return any(hint in f"/{rel_path}" for hint in ELF_PATH_HINTS) or rel_path.endswith(".so")


def partition_family(rel_path: str):
    top = rel_path.split("/", 1)[0]
    return PARTITION_GROUPS.get(top, top)


def bitness_hint(rel_path: str):
    if "/lib64/" in f"/{rel_path}":
        return "64"
    if "/lib/" in f"/{rel_path}":
        return "32"
    return None


def parse_elf_metadata(dump_root: Path, rel_path: str):
    file_path = dump_root / rel_path
    try:
        proc = subprocess.run(
            ["readelf", "-h", "-d", str(file_path)],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return None

    if proc.returncode != 0:
        return None

    elf_class = None
    soname = None
    needed = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line.startswith("Class:"):
            if "ELF64" in line:
                elf_class = "64"
            elif "ELF32" in line:
                elf_class = "32"
        elif "(SONAME)" in line and "[" in line and "]" in line:
            soname = line.split("[", 1)[1].split("]", 1)[0]
        elif "(NEEDED)" in line and "[" in line and "]" in line:
            needed.append(line.split("[", 1)[1].split("]", 1)[0])

    if not needed and soname is None:
        return None

    return {
        "path": rel_path,
        "basename": Path(rel_path).name,
        "partition": partition_family(rel_path),
        "bitness": bitness_hint(rel_path) or elf_class,
        "soname": soname,
        "needed": needed,
    }


def collect_elf_metadata(dump_root: Path, paths, jobs: int, log_enabled: bool):
    metadata = {}
    total = len(paths)
    completed = 0
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as executor:
        future_map = {
            executor.submit(parse_elf_metadata, dump_root, rel_path): rel_path
            for rel_path in paths
        }
        for future in as_completed(future_map):
            rel_path = future_map[future]
            info = future.result()
            completed += 1
            if info is not None:
                metadata[rel_path] = info
                log(log_enabled, f"[scan {completed}/{total}] {rel_path}")
            else:
                log(log_enabled, f"[scan {completed}/{total}] {rel_path} (skip)")

    return dict(sorted(metadata.items()))


def build_provider_map(metadata):
    provider_map = defaultdict(list)
    for rel_path, info in metadata.items():
        keys = [info["basename"]]
        if info["soname"] and info["soname"] not in keys:
            keys.insert(0, info["soname"])
        for key in keys:
            provider_map[key].append(rel_path)

    for key in provider_map:
        provider_map[key] = sorted(set(provider_map[key]))
    return provider_map


def is_system_side(rel_path: str):
    return rel_path.startswith(("system/", "system_ext/", "product/"))


def path_group(rel_path: str):
    if rel_path.startswith("vendor/lib64/"):
        return "vendor/lib64"
    if rel_path.startswith("vendor/lib/"):
        return "vendor/lib"
    if rel_path.startswith("system/"):
        return "system"
    if rel_path.startswith("system_ext/"):
        return "system_ext"
    if rel_path.startswith("product/"):
        return "product"
    return "other"


def choose_provider(requester_info, providers, include_system):
    candidates = list(providers)

    same_partition = [p for p in candidates if partition_family(p) == requester_info["partition"]]
    if same_partition:
        candidates = same_partition

    if requester_info["partition"] == "vendor":
        vendor_candidates = [p for p in candidates if partition_family(p) == "vendor"]
        if vendor_candidates:
            candidates = vendor_candidates

    if requester_info["bitness"] == "64":
        matches = [p for p in candidates if bitness_hint(p) == "64"]
        if matches:
            candidates = matches
    elif requester_info["bitness"] == "32":
        matches = [p for p in candidates if bitness_hint(p) == "32"]
        if matches:
            candidates = matches

    if not include_system:
        filtered = [p for p in candidates if not is_system_side(p)]
        if filtered:
            candidates = filtered

    chosen = sorted(candidates)[0]
    return chosen, sorted(candidates)


def resolve_dependencies(
    metadata,
    provider_map,
    roots,
    tracked,
    excluded,
    source_provided,
    include_system,
    max_depth,
    log_enabled,
):
    additions = {}
    ambiguous = {}
    excluded_hits = {}
    provided_hits = {}
    unresolved = defaultdict(set)
    queue = deque()
    seen = set()
    processed = 0

    for root in roots:
        if root in metadata and root not in seen:
            queue.append((root, 0))
            seen.add(root)

    while queue:
        rel_path, depth = queue.popleft()
        info = metadata.get(rel_path)
        if info is None:
            continue
        processed += 1
        if processed == 1 or processed % 50 == 0:
            log(
                log_enabled,
                (
                    f"[resolve {processed}] queue={len(queue)} "
                    f"additions={len(additions)} unresolved="
                    f"{sum(len(values) for values in unresolved.values())}"
                ),
            )

        if max_depth is not None and depth >= max_depth:
            continue

        for need in info["needed"]:
            if need in SUPPRESSED_NEEDED:
                unresolved["suppressed"].add(need)
                continue

            providers = provider_map.get(need, [])
            if not providers:
                unresolved["missing"].add(need)
                continue

            chosen, considered = choose_provider(info, providers, include_system)

            if not include_system and is_system_side(chosen):
                unresolved["filtered"].add(need)
                continue

            edge = {
                "from": rel_path,
                "needed": need,
                "provider": chosen,
            }
            if len(considered) > 1:
                ambiguous[need] = {
                    "chosen": chosen,
                    "providers": considered,
                }

            if chosen in excluded:
                excluded_hits[chosen] = edge
            elif chosen in source_provided:
                provided_hits[chosen] = {
                    **edge,
                    "modules": source_provided[chosen],
                }
            elif chosen not in tracked and chosen not in additions:
                additions[chosen] = edge

            if chosen in metadata and chosen not in seen:
                seen.add(chosen)
                queue.append((chosen, depth + 1))

    return additions, ambiguous, excluded_hits, provided_hits, unresolved


def emit_human(summary, additions, ambiguous, excluded, provided_by_source, unresolved):
    lines = [
        f"tracked entries: {summary['tracked_entries']}",
        f"tracked ELF roots: {summary['tracked_elf_roots']}",
        f"indexed ELF files: {summary['indexed_elf_files']}",
        f"proposed additions: {summary['proposed_additions']}",
        f"proposed vendor additions: {summary['proposed_vendor_additions']}",
        f"ambiguous SONAMEs: {summary['ambiguous_count']}",
        f"excluded providers: {summary['excluded_count']}",
        f"provided by source: {summary['provided_by_source_count']}",
        f"unresolved names: {summary['unresolved_count']}",
    ]

    grouped = defaultdict(list)
    for rel_path in sorted(additions):
        grouped[path_group(rel_path)].append(rel_path)

    for group_name in sorted(grouped):
        lines.append("")
        lines.append(f"[{group_name}]")
        lines.extend(grouped[group_name])

    sample_edges = [additions[key] for key in sorted(additions)[:40]]
    if sample_edges:
        lines.append("")
        lines.append("Sample dependency edges:")
        for edge in sample_edges:
            lines.append(f"{edge['from']} --[{edge['needed']}]--> {edge['provider']}")

    if ambiguous:
        lines.append("")
        lines.append("Ambiguous providers:")
        for need in sorted(ambiguous):
            item = ambiguous[need]
            lines.append(f"{need}: {item['chosen']} ({', '.join(item['providers'])})")

    if excluded:
        lines.append("")
        lines.append("Excluded providers:")
        for rel_path in sorted(excluded):
            edge = excluded[rel_path]
            lines.append(f"{rel_path} <- {edge['from']} [{edge['needed']}]")

    if provided_by_source:
        lines.append("")
        lines.append("Provided by source:")
        for rel_path in sorted(provided_by_source):
            edge = provided_by_source[rel_path]
            lines.append(
                f"{rel_path} <- {edge['from']} [{edge['needed']}] "
                f"modules={','.join(edge['modules'])}"
            )

    if unresolved:
        lines.append("")
        lines.append("Unresolved names:")
        for category in sorted(unresolved):
            for need in sorted(unresolved[category]):
                lines.append(f"{category}: {need}")

    return "\n".join(lines)


def apply_additions(prop_path: Path, additions):
    if not additions:
        return False

    with prop_path.open("r", encoding="utf-8") as handle:
        existing = handle.readlines()

    block = [AUTO_HEADER + "\n"]
    block.extend(f"{path}\n" for path in sorted(additions))
    block.append("\n")

    with prop_path.open("w", encoding="utf-8") as handle:
        handle.writelines(block + existing)
    return True


def main():
    args = parse_args()
    log_enabled = not args.quiet
    if not args.dump_root:
        raise SystemExit("--dump-root is required and must point to the extracted stock dump root.")
    dump_root = Path(args.dump_root).expanduser().resolve()
    prop_path = Path(args.proprietary).expanduser().resolve()
    exclude_path = Path(args.exclude).expanduser().resolve() if args.exclude else None
    module_info_path = Path(args.module_info).expanduser().resolve() if args.module_info else None

    if not dump_root.is_dir():
        raise SystemExit(f"dump root not found: {dump_root}")
    if not prop_path.is_file():
        raise SystemExit(f"proprietary file not found: {prop_path}")
    if exclude_path is not None and not exclude_path.is_file():
        raise SystemExit(f"exclude file not found: {exclude_path}")
    if module_info_path is not None and not module_info_path.is_file():
        raise SystemExit(f"module-info file not found: {module_info_path}")

    all_files_path = choose_all_files_path(dump_root, args.all_files)
    log(log_enabled, f"Starting offline blob resolver")
    log(log_enabled, f"  dump root: {dump_root}")
    log(log_enabled, f"  proprietary: {prop_path}")
    log(log_enabled, f"  all-files: {all_files_path}")
    if exclude_path is not None:
        log(log_enabled, f"  exclude: {exclude_path}")
    if module_info_path is not None:
        log(log_enabled, f"  module-info: {module_info_path}")
    log(log_enabled, f"  jobs: {max(1, args.jobs)}")

    tracked, roots, tracked_entries = load_tracked_entries(prop_path)
    excluded, exclude_entries = load_excluded_entries(exclude_path) if exclude_path is not None else (set(), [])
    source_provided = load_module_info(module_info_path) if module_info_path is not None else {}
    log(log_enabled, f"Loaded proprietary entries: {len(tracked_entries)}")
    if exclude_path is not None:
        log(log_enabled, f"Loaded exclude entries: {len(exclude_entries)}")
    if module_info_path is not None:
        log(log_enabled, f"Loaded source-provided paths: {len(source_provided)}")
    all_paths = read_all_paths(all_files_path)
    log(log_enabled, f"Loaded all_files entries: {len(all_paths)}")
    scan_paths = [path for path in all_paths if should_scan_path(path) and (dump_root / path).is_file()]
    log(log_enabled, f"Candidate scan paths: {len(scan_paths)}")
    log(log_enabled, "Starting parallel readelf scan...")
    metadata = collect_elf_metadata(dump_root, scan_paths, args.jobs, log_enabled)
    log(log_enabled, f"Scan complete: indexed {len(metadata)} ELF files")
    provider_map = build_provider_map(metadata)
    log(log_enabled, f"Provider map built: {len(provider_map)} names")
    log(log_enabled, f"Starting dependency resolution from {sum(1 for root in roots if root in metadata)} ELF roots...")
    additions, ambiguous, excluded_hits, provided_hits, unresolved = resolve_dependencies(
        metadata=metadata,
        provider_map=provider_map,
        roots=roots,
        tracked=tracked,
        excluded=excluded,
        source_provided=source_provided,
        include_system=args.include_system,
        max_depth=args.max_depth,
        log_enabled=log_enabled,
    )

    vendor_additions = [path for path in additions if path.startswith("vendor/")]
    unresolved_count = sum(len(values) for values in unresolved.values())
    log(
        log_enabled,
        (
            f"Resolution complete: additions={len(additions)} "
            f"vendor_additions={len(vendor_additions)} ambiguous={len(ambiguous)} "
            f"excluded={len(excluded_hits)} "
            f"provided_by_source={len(provided_hits)} "
            f"unresolved={unresolved_count}"
        ),
    )
    summary = {
        "tracked_entries": len(tracked_entries),
        "tracked_elf_roots": sum(1 for root in roots if root in metadata),
        "indexed_elf_files": len(metadata),
        "proposed_additions": len(additions),
        "proposed_vendor_additions": len(vendor_additions),
        "ambiguous_count": len(ambiguous),
        "excluded_count": len(excluded_hits),
        "provided_by_source_count": len(provided_hits),
        "unresolved_count": unresolved_count,
    }

    if args.apply:
        log(log_enabled, f"Applying {len(additions)} additions to {prop_path}")
        apply_additions(prop_path, additions)
        log(log_enabled, "Apply complete")

    payload = {
        "summary": summary,
        "additions": {key: additions[key] for key in sorted(additions)},
        "edges": [additions[key] for key in sorted(additions)],
        "ambiguous": {key: ambiguous[key] for key in sorted(ambiguous)},
        "excluded": {key: excluded_hits[key] for key in sorted(excluded_hits)},
        "provided_by_source": {key: provided_hits[key] for key in sorted(provided_hits)},
        "unresolved": {key: sorted(values) for key, values in sorted(unresolved.items())},
    }

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print(emit_human(summary, additions, ambiguous, excluded_hits, provided_hits, unresolved))


if __name__ == "__main__":
    main()
