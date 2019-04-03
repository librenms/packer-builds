#!/usr/bin/env bash

CURL='/usr/bin/env curl'
JQ='/usr/bin/env jq'
PACKER='/usr/bin/env packer'
RE='^[0-9]+([.][0-9]+)?$'
FIND='/usr/bin/env find'
IMAGES="centos-7.5-x86_64
ubuntu-18.04-amd64"
BUILDERS="virtualbox-iso"

echo "Removing old files in output dirs"
FILES=$($FIND ./output-* -type f -print)
for FILE in $FILES; do
    echo "Removing $FILE"
    rm -f $FILE
done

echo "Please enter your GitHub personal access token (we don't save it):"
read -s TOKEN

LATEST_TAG=$($CURL -s https://api.github.com/repos/librenms/librenms/releases/latest | $JQ -r ".tag_name")

if ! [[ "$LATEST_TAG" =~ $RE ]] ; then
    echo "Tag not found"; exit 1;
fi

echo "Tag $LATEST_TAG, found, building images"

for IMAGE in $IMAGES; do
    for BUILDER in $BUILDERS; do
        echo "Building $IMAGE with $BUILDER"
        BUILD=$($PACKER build -force -only=$BUILDER -var "librenms_version=$LATEST_TAG" -var 'headless=true' $IMAGE.json)
        if [ $? != 0 ] ; then
            echo "Build failed:"
            echo $BUILD
        else
            echo "Build completed"
        fi
    done
done

echo "Creating new release $LATEST_TAG"

UPLOAD_URL=$($CURL -s https://api.github.com/repos/librenms/packer-builds/releases -H "Authorization: token $TOKEN" -X POST --header "Content-Type: application/json" -d "{\"tag_name\":\"$LATEST_TAG\",\"name\":\"v$LATEST_TAG\"}" | $JQ -r ".upload_url")
UPLOAD_URL="${UPLOAD_URL//\{\?name,label\}/}"
FILES=$($FIND ./output-* -type f -print)
for FILE in $FILES; do
    IFS='/' read -a OVA <<< "$FILE"
    NAME=${OVA[2]}
    echo "$CURL -s \"$UPLOAD_URL?name=$NAME\" -H \"Authorization: token <TOKEN>\" --data-binary @\"$FILE\" -H \"Content-Type: application/tar\""
    UPLOAD=$($CURL -s "$UPLOAD_URL?name=$NAME" -H "Authorization: token $TOKEN" --data-binary @"$FILE" -H "Content-Type: application/tar")
    if [ $? != 0 ] ; then
        echo "Upload failed:"
        echo $UPLOAD
    else
        echo "Upload completed"
    fi
done
