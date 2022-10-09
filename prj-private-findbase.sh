#!/usr/bin/env bash

# vi: ft=bash
set -euo pipefail

BASE=${1}

find_base() {
    BASE=$1
    BASE="$(realpath "${BASE}")"
    while [ ! -f "${BASE}/.prj" ]
    do
        BASE="$(dirname "${BASE}")"
        if [ "${BASE}" = "/" ]
        then
            break
        fi
    done

    if [ ! -f "${BASE}/.prj" ]
    then
        echo "ERROR: could not find any 'prj' projects." 1>&2
        exit 1
    fi
    echo "${BASE}"
}

BASE="$(find_base ${BASE})"

echo "${BASE}"
