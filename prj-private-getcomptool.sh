#!/usr/bin/env bash

# vi: ft=bash
set -euo pipefail

MODE="$1"
COMP="$2"
COMP_LEVEL="$3"
CPUS="${4}"

if [ "${MODE}" != "compress" ] && [ "${MODE}" != "decompress" ]
then
    echo "ERROR: Got invalid mode ${MODE}. Choose compress or decompress" >&2
    exit 1
fi

# Handle common extensions
case "${COMP}" in
    gz|gzip) COMP="gzip";;
    bgz|bzip2) COMP="bzip2";;
    zst|zstd) COMP="zstd";;
    *)
        echo "ERROR: somehow we ended up with an unsupported compression tool. We need one of gzip, bzip2, or zstd" >&2
        exit 1
	;;
esac
	


if [ "${MODE}" == "compress" ]
then
    case "${COMP}" in
        gzip|bgzip2)
            if [ "${COMP_LEVEL}" -lt 1 ] || [ "${COMP_LEVEL}" -gt 9 ]
            then
                echo "WARNING: compression levels for ${COMP} must be between 1 and 9. Got ${COMP_LEVEL}." >&2
                [ "${COMP}" == "gzip" ] && COMP_LEVEL=6 || COMP_LEVEL=9
                echo "WARNING: resetting to ${COMP} default level: ${COMP_LEVEL}."
            fi
            ;;
        zstd)
            if [ "${COMP_LEVEL}" -lt 1 ] || [ "${COMP_LEVEL}" -gt 19 ]
            then
                echo "WARNING: compression levels for zstd must be between 1 and 19. Got ${COMP_LEVEL}." >&2
                COMP_LEVEL=19
                echo "WARNING: resetting to ${COMP} default level: ${COMP_LEVEL}."
            fi
            ;;
    esac
    COMP_LEVEL_FLAG="-${COMP_LEVEL}"
else
    COMP_LEVEL_FLAG=""
fi

if [ "${COMP}" == "gzip" ]
then
    [ "${MODE}" == "compress" ] && MODE_FLAG="" || MODE_FLAG="--decompress"
    if command -v pigz > /dev/null
    then
        NPROC=""
        [ "${CPUS}" -gt 0 ] && NPROC="--processes ${CPUS}"
        TOOL="pigz ${NPROC} ${COMP_LEVEL_FLAG} ${MODE_FLAG} --keep --stdout"
    elif command -v gzip > /dev/null
    then
        TOOL="gzip ${MODE_FLAG} ${COMP_LEVEL_FLAG} --rsyncable --keep --stdout"
    else
        echo "ERROR: no gzip tools are available. Please install gzip or pigz!" >&2
        exit 1
    fi
elif [ "${COMP}" == "bzip2" ]
then
    [ "${MODE}" == "compress" ] && MODE_FLAG="--compress" || MODE_FLAG="--decompress"
    if command -v pbzip2 > /dev/null
    then
        NPROC=""
        [ "${CPUS}" -gt 0 ] && NPROC="-p${CPUS}"
        TOOL="pbzip2 ${NPROC} ${COMP_LEVEL_FLAG} ${MODE_FLAG}  --keep --stdout"
    elif command -v lbzip2 > /dev/null
    then
        NPROC=""
        [ "${CPUS}" -gt 0 ] && NPROC="-n ${CPUS}"
        TOOL="lbzip2 ${NPROC} ${COMP_LEVEL_FLAG} ${MODE_FLAG}  --keep --stdout"
    elif command -v bzip2 > /dev/null
    then
        TOOL="bzip2 ${COMP_LEVEL_FLAG} ${MODE_FLAG} --keep --stdout"
    else
        echo "ERROR: no bzip2 tools are available. Please install bzip2, lbzip2, or pbzip2!" >&2
        exit 1
    fi
elif [ "${COMP}" == "zstd" ]
then
    [ "${MODE}" == "compress" ] && MODE_FLAG="--compress" || MODE_FLAG="--decompress"
    if command -v zstd > /dev/null
    then
        NPROC=""
        [ "${CPUS}" -gt 0 ] && NPROC="-T${CPUS}"
        TOOL="zstd ${NPROC} ${COMP_LEVEL_FLAG} ${MODE_FLAG} --keep --stdout"
    else
        echo "ERROR: no zstd tools are available. Please install zstd!" >&2
        exit 1
    fi
else
    echo "ERROR: somehow we ended up with an unsupported compression tool. We need one of gzip, bzip2, or zstd" >&2
    exit 1
fi

echo "${TOOL}"
