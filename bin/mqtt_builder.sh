#!/bin/bash

thisDir=$(pwd)
scriptDir=$(dirname $0)
scriptFile=$(basename $0)
[[ -f "/${scriptDir}/${scriptFile}" ]] || scriptDir="${thisDir}/${scriptDir}"

readonly export repoUrl="git@bitbucket.org:test/deviceclient.git"

. "${scriptDir}/_common_functions.sh"

function show_usage (){
    echo "Usage: 
    $0 --workspace <path> --build_openssl --build_curl --device_cert <path> --private_key <path> --ca_cert <path>

Note: curl and openssl are not built by default
"
    exit 127
}

## MAIN
[[ $# -lt 8 ]] && show_usage
while [[ $# -gt 0 ]]; do
case "$1" in
    "--workspace"     ) export workspacePath=$2 ; shift 2 ;;
    "--build_openssl" ) export buildLibraries="${buildLibraries},openssl" ; shift 1 ;;
    "--build_curl"    ) export buildLibraries="${buildLibraries},curl" ; shift 1 ;;
    "--device_cert"   ) export deviceCert="$2" ; shift 2 ;;
    "--private_key"   ) export privateKey="$2" ; shift 2 ;;
    "--ca_cert"       ) export caCert="$2" ; shift 2 ;;
    * ) die "Invalid argument \"$1\""
esac
done

export ROOT_DIR="${workspacePath}/s2ibin/deviceclient"
mkdir -p ${ROOT_DIR}

git_clone $repoUrl ${ROOT_DIR}

## read the file-content
[[ -f "${deviceCert}" ]] || die "Unable to read --device_cert:${deviceCert}"
[[ -f "${privateKey}" ]] || die "Unable to read --private_key:${privateKey}"
[[ -f "${caCert}" ]] || die "Unable to read --ca_cert:${caCert}"

create_header_file $deviceCert $privateKey $caCert "${ROOT_DIR}/device/src"
build_arm_openssl_curl $ROOT_DIR $buildLibraries
build_arm_image $ROOT_DIR "${ROOT_DIR}/device/cmake/toolchain.linux-arm11.cmake"

