#!/usr/bin/env bash

IMAGES=$(echo ${IMAGES:-"centos-7.5-x86_64;ubuntu-18.04-amd64"} | tr ';' '\n')
BUILDERS=$(echo ${BUILDERS:-"virtualbox-iso"} | tr ';' '\n')
RE='^[0-9]+([.][0-9]+)?$'
#LATEST_TAG=$(curl -s https://api.github.com/repos/librenms/librenms/releases/latest | jq -r ".tag_name")
LATEST_TAG=1.45

echo "Removing old files"
rm -rf ./build/*

if ! [[ "$LATEST_TAG" =~ $RE ]] ; then
    echo "Tag '$LATEST_TAG' not found"; exit 1;
fi

echo "Building images for $LATEST_TAG tag"
for IMAGE in ${IMAGES}; do
    for BUILDER in ${BUILDERS}; do
        echo "Building $IMAGE with $BUILDER"
        BUILD=$(PACKER_LOG=1 packer build -force -only=${BUILDER} -var 'librenms_version=$LATEST_TAG' -var 'headless=true' ${IMAGE}.json)
        if [[ $? != 0 ]] ; then
            echo "Build failed:"
            echo ${BUILD}
        else
            echo "Build completed"
        fi
    done
done
