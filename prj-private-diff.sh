#!/usr/bin/env bash

# vi: ft=bash
set -euo pipefail

difference() {
    grep --invert-match --fixed-strings --line-regexp --file $2 $1 || :
}


intersection() {
    grep --fixed-strings --line-regexp --file $2 $1 || :
}

DIFF="$(cat ${1:-/dev/stdin})"

OLD="$(echo "${DIFF}" | ( grep '^<' || :) | cut -d' ' -f 4-)"
NEW="$(echo "${DIFF}" | ( grep '^>' || :) | cut -d' ' -f 4-)"

NEWFILES=$(difference <(echo "${NEW}") <(echo "${OLD}"))
[ ! -z "${NEWFILES:-}" ] && (echo "${NEWFILES}" | sed 's/^/NEW\t/') || :

DELETEDFILES=$(difference <(echo "${OLD}") <(echo "${NEW}"))
[ ! -z "${DELETEDFILES:-}" ] && (echo "${DELETEDFILES}" | sed 's/^/DELETED\t/') || :

MODIFIEDFILES=$(intersection <(echo "${OLD}") <(echo "${NEW}"))
[ ! -z "${MODIFIEDFILES:-}" ] && (echo "${MODIFIEDFILES}" | sed 's/^/MODIFIED\t/') || :

exit 0
