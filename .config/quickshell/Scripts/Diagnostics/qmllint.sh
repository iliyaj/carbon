#!/usr/bin/env bash
set -uo pipefail

QMLLINT=/usr/lib/qt6/bin/qmllint
if [ ! -x "$QMLLINT" ]; then
    echo "qmllint.sh: Qt6 qmllint not found at $QMLLINT (install qt6-declarative)" >&2
    exit 2
fi

files=()
for f in "$@"; do
    if [ ! -e "$f" ]; then
        echo "qmllint.sh: no such file: $f" >&2
        exit 2
    fi
    files+=("$(realpath "$f")")
done

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root" || exit 2

if [ ${#files[@]} -eq 0 ]; then
    mapfile -t files < <(find . -name '*.qml' -not -path './.git/*' | sort)
fi

status=0
for f in "${files[@]}"; do
    out=$("$QMLLINT" --import disable --unqualified disable --unresolved-type disable \
        --missing-property disable --signal-handler-parameters disable \
        --unused-imports disable "$f" 2>&1)
    rc=$?
    if [ -n "$out" ] || [ $rc -ne 0 ]; then
        printf '### %s (rc=%s)\n%s\n' "${f#"$root"/}" "$rc" "${out:-<no output; rc $rc means a parse error>}"
        status=1
    fi
done

[ $status -eq 0 ] && echo "qmllint: clean (${#files[@]} files)"
exit $status
