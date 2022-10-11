#!/usr/bin/env bash

# vi: ft=bash
set -euo pipefail

BASE="${1:-}"
HEREONLY="${2:-False}"

if [ ! -z "${HEREONLY}" ] && [ "${HEREONLY}" != "False" ]
then
    BASE=$(realpath "${BASE}")
    if [ -f "${BASE}/.prj" ]
    then
        echo "${BASE}"
        exit 0
    else
        echo "ERROR: no base file found at ${BASE}" 1>&2
	echo "${BASE}"
        exit 2
    fi
fi


find_base() {
    BASE_=$1
    BASE_="$(realpath "${BASE_}")"
    while [ ! -f "${BASE_}/.prj" ]
    do
        BASE_="$(dirname "${BASE_}")"
        if [ "${BASE_}" = "/" ]
        then
	    BASE_=""
            break
        fi
    done

    if [ ! -f "${BASE_}/.prj" ]
    then
        echo "ERROR: could not find any 'prj' projects." 1>&2
	echo "${BASE_}"
        exit 2
    fi
    echo "${BASE_}"
}

EC=0
BASE_=$(find_base "${BASE}") || EC=$?

if [ -z "${BASE_}" ]
then
    echo "${BASE}"
else
    echo "${BASE_}"
fi
exit "${EC}"
