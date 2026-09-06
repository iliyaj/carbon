#!/usr/bin/env bash
# /usr/bin/qmllint is Qt5 and exits 255 on Qt6 pragmas without printing, so it silently
# checks nothing. This runs Qt6 qmllint with Carbon's `qs.*` module import path.
#
# The tree is linted in place, so this sees exactly what qmlls reports in an editor. Keeping
# the two in agreement is the point: `qs.*` imports and the checked-in qmldir files exist so
# that both resolve Carbon's own types.
set -uo pipefail

usage() {
    cat <<'EOF'
Usage: qmllint.sh [--sync-qmldir] [QML_FILE ...]

Lint the given files, or every QML file in the Carbon Quickshell tree when no files are given.
Paths may be absolute or relative to the caller, but must be inside .config/quickshell.

  --sync-qmldir   Regenerate the qmldir files instead of linting. Run this after adding,
                  removing or renaming a QML type in a directory imported as a qs.* module.
EOF
}

sync_qmldir=0
files=()
for arg in "$@"; do
    case "$arg" in
        -h|--help)
            usage
            exit 0
            ;;
        --sync-qmldir)
            sync_qmldir=1
            ;;
        *)
            files+=("$arg")
            ;;
    esac
done

QMLLINT=/usr/lib/qt6/bin/qmllint
if [ ! -x "$QMLLINT" ]; then
    echo "qmllint.sh: Qt6 qmllint not found at $QMLLINT (install qt6-declarative)" >&2
    exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
sync_script="$root/Scripts/Diagnostics/qmldir-sync.py"
import_path=$(cd "$root/../../.qmlmodules" 2>/dev/null && pwd)
if [ -z "$import_path" ]; then
    echo "qmllint.sh: missing .qmlmodules/qs symlink at the repo root" >&2
    exit 2
fi

if [ $sync_qmldir -eq 1 ]; then
    python3 "$sync_script" "$root"
    exit $?
fi

# A stale qmldir makes every type in that module unresolvable, which buries real findings.
if ! python3 "$sync_script" "$root" --check; then
    exit 2
fi

targets=()
for f in "${files[@]}"; do
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

cd "$root" || exit 2
if [ ${#targets[@]} -eq 0 ]; then
    mapfile -t targets < <(find . -name '*.qml' -printf '%P\n' | sort)
fi

finding_files=0
for f in "${targets[@]}"; do
    out=$("$QMLLINT" -I "$import_path" "$f" 2>&1)
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
