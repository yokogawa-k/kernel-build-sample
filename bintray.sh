#!/bin/bash
# ref. https://github.com/bintray/bintray-examples/blob/master/bash-example/pushToBintray.sh

set -e
set -u


function get_latest_revision() {
    CUSTOM_REVISION=1
    
    if [ -f ./env.txt ]; then
        source ./env.txt
    else
        # revision 1
        echo ${CUSTOM_REVISION}
        exit 0
    fi

    CURL="curl -u${BINTRAY_USER}:${BINTRAY_API_KEY} -H Content-Type:application/json -H Accept:application/json"
    
    while true; do
        PCK_NAME="linux-image-${LATEST}-${CUSTOM_REVISION}-${CUSTOM_NAME}"
        if [ "$(${CURL} --write-out '%{http_code}' --silent --output /dev/null -X GET ${BINTRAY_API}/packages/${BINTRAY_USER}/${BINTRAY_REPO}/${PCK_NAME})"  -eq 200 ]; then
            echo "Package $PACK_NAME exist"
        else
            break
        fi
        (( CUSTOM_REVISION += 1 ))
    done
    
    echo ${CUSTOM_REVISION}
}    

function create_package() {
    case ${PCK_FILENAME} in
        linux-image-*)
            DESC="Custom Linux kernel binary image for version ${LATEST}-${CUSTOM_REVISION}-${CUSTOM_NAME}"
            ;;
        linux-headers-*)
            DESC="Custom Header files related to Linux kernel for version ${LATEST}-${CUSTOM_REVISION}-${CUSTOM_NAME}"
            ;;
        *)
            echo >&2 "${PCK_FILENAME} is unsupported name."
            exit 4
            ;;
    esac

    echo "Creating package ${PCK_NAME}..."
    data="{
    \"name\": \"${PCK_NAME}\",
    \"desc\": \"${DESC}\",
    \"licenses\": [\"Apache-2.0\", \"GPL-2.0\"],
    \"github_repo\": \"yokogawa-k/kernel-build\",
    \"vcs_url\": \"https://github.com/yokogawa-k/kernel-build\",
    \"labels\": [\"debian\", \"kernel\"]
    }"

    ${CURL} -X POST -d "${data}" ${BINTRAY_API}/packages/${BINTRAY_USER}/${BINTRAY_REPO}
}

function deploy_package() {
    if (upload_content); then
        echo "Publishing ${PCK_NAME}..."
        ${CURL} -X POST ${BINTRAY_API}/content/${BINTRAY_USER}/${BINTRAY_REPO}/${PCK_NAME}/${LATEST}-${CUSTOM_REVISION}/publish -d "{ \"discard\": \"false\" }"
    else
        echo "[SEVERE] First you should upload your deb ${PCK_NAME}"
    fi
}

function upload_content() {
    echo "Uploading ${PCK_NAME}..."
    status=$( \
            ${CURL} --write-out %{http_code} --silent --output /dev/null -T ${PCK_FILENAME} \
                -H X-Bintray-Debian-Distribution:jessie \
                -H X-Bintray-Debian-Component:main \
                -H X-Bintray-Debian-Architecture:amd64 \
                -X PUT \
                ${BINTRAY_API}/content/${BINTRAY_USER}/${BINTRAY_REPO}/${PCK_NAME}/${LATEST}-${CUSTOM_REVISION}/${PCK_FILENAME}
            )

    if [ "${status}" -eq "201" ]; then
        echo "success"
        return 0
    else
        echo "fail"
        return 1
    fi
}

function deploy() {
    if [ -f ./env.txt ]; then
        source ./env.txt
    else
        echo >&2 "Environmentfile(env.txt) not found."
        exit 4
    fi

    CURL="curl -u${BINTRAY_USER}:${BINTRAY_API_KEY} -H Content-Type:application/json -H Accept:application/json"

    PCK_FILENAMES=(
        "linux-image-${LATEST}-${CUSTOM_REVISION}-${CUSTOM_NAME}_${LATEST}+${CUSTOM_REVISION}.${CUSTOM_NAME}_amd64.deb"
        "linux-headers-${LATEST}-${CUSTOM_REVISION}-${CUSTOM_NAME}_${LATEST}+${CUSTOM_REVISION}.${CUSTOM_NAME}_amd64.deb"
    )

    for f in "${PCK_FILENAMES[@]}"; do
        if [ -f ${f} ]; then
            :
        else
            echo >&2 "${f} not found."
            exit 4
        fi
    done

    for p in "${PCK_FILENAMES[@]}"; do
        PCK_NAME=${p%_${LATEST}+${CUSTOM_REVISION}.${CUSTOM_NAME}_*}
        PCK_FILENAME=${p}
        create_package
        deploy_package
    done
}

function usage() {
    echo >&2 "Usage: ${0} COMMAND"
    echo >&2 ""
    echo >&2 "Commands:"
    echo >&2 "    get_revision  get new revision."
    echo >&2 "    deploy        upload and deploy packages."
    exit 3
}

if [ "$#" -ne 1 ]; then
    usage
fi

case "${1}" in
    get_revision)
        get_latest_revision
        ;;
    deploy)
        deploy
        ;;
    *)
        usage
        ;;
esac

