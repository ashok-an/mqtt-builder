#!/bin/bash

function info (){
    echo "$(date +%H:%M:%S) ${*}"
}

function die (){
    echo "Error: ${*}" 1>&2
    exit 1
}

function git_clone (){
    local repoUrl=$1
    local targetDir=$2

    git --version &>/dev/null || die "Unable to locate git executable in your path"
    mkdir -p ${targetDir}
    pushd ${targetDir} &>/dev/null || die "Unable to cd ${targetDir}"
        git init
        git remote add origin ${repoUrl}
        git clone ${repoUrl} . || die "Unable to clone ${repoUrl}"
    popd &>/dev/null    
}

function create_header_file (){
    local deviceCert=$1
    local privateKey=$2
    local caCert=$3

    local targetDir=$4

    info "Updating ${targetDir}/cert.h ..."

    [[ "${deviceCert}" ]] || die "No value passed for \"dev_cert\""
    [[ "${privateKey}" ]] || die "No value passed for \"dev_private_key\""
    [[ "${caCert}" ]] || die "No value passed for \"ca_cert\""
    [[ -d "${targetDir}" ]] || die "Target directory \"$targetDir\" does not exist"
    [[ -f "cert.h.template" ]] || die "Unable to locate cert.h.template under $(pwd)"
    
    sed -e "s/__DEV_CERT_HERE__/${deviceCert}/"    \
        -e "s/__PRIVATE_KEY_HERE__/${privateKey}/" \
        -e "s/__CA_CERT_HERE__/${caCert}/" cert.h.template > ${targetDir}/cert.h
}

function build_arm_openssl_curl (){
    local rootDir=$1
    local librariesToBuild=$2
    export ROOT_DIR="${rootDir}"
    export INSTALL_DIR="${rootDir}/device/lib/arm/32bit"
    export CROSSCOMP_DIR="${ROOT_DIR}/device/tools/arm/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin"

    [[ -d "${INSTALL_DIR}" ]] || die "Unable to locate INSTALL_DIR:${INSTALL_DIR}"
    [[ -d "${CROSSCOMP_DIR}" ]] || die "Unable to locate CROSSCOMP_DIR:${CROSSCOMP_DIR}"
    
    if echo ${librariesToBuild} | grep -qs "openssl"; then
        info "Building arm-openssl ..."
        pushd ${INSTALL_DIR}/../src/openssl &>/dev/null || die "Unable to cd ${INSTALL_DIR}/../src/openssl"
            ./configure linux-generic32 disable-shared --prefix=${INSTALL_DIR} --openssldir=${INSTALL_DIR}/openssl --cross-compile-prefix=${CROSSCOMP_DIR}/arm-linux-gnueabihf-  || die "configure failed"
            make || die "make failed"
            make install || die "make install failed"     
        popd &>/dev/null 
    else
        info "openssl build skipped"
    fi

    if echo ${librariesToBuild} | grep -qs "curl"; then
        export CROSS_COMPILE=${CROSSCOMP_DIR}/arm-linux-gnueabihf
        export AR=${CROSS_COMPILE}-ar
        export AS=${CROSS_COMPILE}-as
        export LD=${CROSS_COMPILE}-ld
        export RANLIB=${CROSS_COMPILE}-ranlib
        export CC=${CROSS_COMPILE}-gcc
        export NM=${CROSS_COMPILE}-nm
        info "Building arm-curl ..."
        pushd ${INSTALL_DIR}/../src/curl &>/dev/null || die "Unable to cd ${INSTALL_DIR}/../src/curl"
            ./configure --prefix=${INSTALL_DIR} --target=arm-linux-gnueabihf --host=arm-linux-gnueabihf --build=i586-pc-linux-gnu || die "configure failed"
            make || die "make failed"
            make install || die "make install failed"     
        popd &>/dev/null 
        unset CROSS_COMPILE AR AS LD RANLIB CC NM
    else
        info "curl build skipped"
    fi
    unset ROOT_DIR INSTALL_DIR CROSSCOMP_DIR
}

function build_arm_image (){
    local rootDir=$1
    local toolchainFile=$2

    export ROOT_DIR=${rootDir}
    [[ -d "${ROOT_DIR}" ]] || die "Unable to locate ROOT_DIR:${ROOT_DIR}"
    [[ -f "$toolchainFile" ]] || die "Unable to locate toolchain file:${toolchainFile}"

    info "Building the image using ${toolchainFile} ..."
    cmake -DPAHO_BUILD_STATIC=TRUE -DPAHO_WITH_SSL=TRUE -DCROSS_COMPILE_ARM=TRUE -DCMAKE_TOOLCHAIN_FILE=${toolchainFile} ${ROOT_DIR}/device || die "cmake failed"
    make || die "make failed"
    
}

