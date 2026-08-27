#!/usr/bin/env bash
# /usr/bin/qmllint is Qt5 and exits 255 on Qt6 pragmas without printing, so it silently
# checks nothing. This runs Qt6's against a copy with root:/ imports and singletons resolved.
set -uo pipefail

QMLLINT=/usr/lib/qt6/bin/qmllint
if [ ! -x "$QMLLINT" ]; then
    echo "qmllint.sh: Qt6 qmllint not found at $QMLLINT (install qt6-declarative)" >&2
    exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
targets=()
for f in "$@"; do
    [ -e "$f" ] || { echo "qmllint.sh: no such file: $f" >&2; exit 2; }
    targets+=("$(realpath --relative-to="$root" "$(realpath "$f")")")
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
    prev = qd.read_text().rstrip() + "\n" if qd.exists() else ""
    qd.write_text(prev + "".join(f"singleton {n} 1.0 {n}.qml\n" for n in sorted(names)))
PY

cd "$work/src" || exit 2
if [ ${#targets[@]} -eq 0 ]; then
    mapfile -t targets < <(find . -name '*.qml' -printf '%P\n' | sort)
fi

# Quickshell's own types and nested QtObject properties do not resolve standalone; these
# categories are noise here, everything else reports.
MUTED=(--missing-property disable --unqualified disable --unresolved-type disable
       --signal-handler-parameters disable --unused-imports disable --property-override disable
       --import disable --uncreatable-type disable --missing-type disable)

status=0
for f in "${targets[@]}"; do
    out=$("$QMLLINT" "${MUTED[@]}" "$f" 2>&1)
    rc=$?
    if [ -n "$out" ] || [ $rc -ne 0 ]; then
        printf '### %s (rc=%s)\n%s\n' "$f" "$rc" "${out:-<no output; rc $rc means a parse error>}"
        status=1
    fi
done

[ $status -eq 0 ] && echo "qmllint: clean (${#targets[@]} files)"
exit $status
