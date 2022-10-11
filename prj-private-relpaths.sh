#!/usr/bin/env bash

# vi: ft=bash
set -euo pipefail

BASE=$1
shift

if [ $# -lt 1 ]
then
    echo "ERROR: didn't get any files" >&2
    exit 1
fi

BASE="$(prj-private-findbase.sh ${BASE})"

for TARGET in "$@"
do
    TARGET=$(echo "${TARGET}" | (grep -v '^[[:space:]]*$' || :))
    if [ -z "${TARGET:-}" ]
    then
        continue
    fi
    realpath --no-symlinks "${TARGET}" \
        | awk -v DIR="${BASE}" '{print substr($0, length(DIR) + 2)}'
done
