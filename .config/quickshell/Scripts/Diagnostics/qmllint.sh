#!/usr/bin/env bash
# /usr/bin/qmllint is Qt5 and exits 255 on Qt6 pragmas without printing, so it silently
# checks nothing. This runs Qt6 qmllint against a copy with root:/ imports and singletons resolved.
set -uo pipefail

usage() {
    cat <<'EOF'
Usage: qmllint.sh [QML_FILE ...]

Lint the given files, or every QML file in the Carbon Quickshell tree when no files are given.
Paths may be absolute or relative to the caller, but must be inside .config/quickshell.
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
esac

QMLLINT=/usr/lib/qt6/bin/qmllint
if [ ! -x "$QMLLINT" ]; then
    echo "qmllint.sh: Qt6 qmllint not found at $QMLLINT (install qt6-declarative)" >&2
    exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
targets=()
for f in "$@"; do
    [ -f "$f" ] || { echo "qmllint.sh: no such file: $f" >&2; exit 2; }
    source_path=$(realpath "$f")
    case "$source_path" in
        "$root"/*.qml)
            targets+=("$(realpath --relative-to="$root" "$source_path")")
            ;;
        "$root"/*)
            echo "qmllint.sh: not a QML file: $f" >&2
            exit 2
            ;;
        *)
            echo "qmllint.sh: file is outside $root: $f" >&2
            exit 2
            ;;
    esac
done

work=$(mktemp -d) || exit 2
trap 'rm -rf "$work"' EXIT

python3 - "$root" "$work" <<'PY' || exit 2
import os, pathlib, re, shutil, sys
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]) / "src"
shutil.copytree(src, dst, ignore=shutil.ignore_patterns(".git"))
pat = re.compile(r'import\s+"root:/([^"]*)"')
for f in dst.rglob("*.qml"):
    text = f.read_text()
    new = pat.sub(lambda m: 'import "%s"' % os.path.relpath((dst / m.group(1)).resolve(), f.parent), text)
    if new != text:
        f.write_text(new)
singletons = {}
for f in dst.rglob("*.qml"):
    if re.search(r'^\s*pragma\s+Singleton', f.read_text()[:400], re.M):
        singletons.setdefault(f.parent, []).append(f.stem)
for d, names in singletons.items():
    qd = d / "qmldir"
    prev = qd.read_text() if qd.exists() else ""
    missing = [n for n in sorted(names) if not re.search(
        rf"^\s*(?:(?:internal|singleton)\s+)*{re.escape(n)}(?:\s|$)", prev, re.M
    )]
    if missing:
        separator = "" if not prev or prev.endswith("\n") else "\n"
        qd.write_text(prev + separator + "".join(
            f"singleton {n} 1.0 {n}.qml\n" for n in missing
        ))
PY

cd "$work/src" || exit 2
if [ ${#targets[@]} -eq 0 ]; then
    mapfile -t targets < <(find . -name '*.qml' -printf '%P\n' | sort)
fi

finding_files=0
for f in "${targets[@]}"; do
    out=$("$QMLLINT" "$f" 2>&1)
    rc=$?
    if [ -n "$out" ] || [ $rc -ne 0 ]; then
        if [ $rc -eq 0 ]; then
            printf '### %s\n%s\n' "$f" "$out"
        else
            printf '### %s (qmllint exit %s)\n%s\n' "$f" "$rc" "${out:-<no output; nonzero exit usually means a parse error>}"
        fi
        finding_files=$((finding_files + 1))
    fi
done

if [ $finding_files -eq 0 ]; then
    echo "qmllint: clean (${#targets[@]} files)"
    exit 0
fi

echo "qmllint: findings in $finding_files of ${#targets[@]} files"
exit 1
