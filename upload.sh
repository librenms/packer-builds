#!/usr/bin/env bash

CURL='/usr/bin/env curl'
JQ='/usr/bin/env jq'
PACKER='/usr/bin/env packer'
RE='^[0-9]+[.][0-9]+([.][0-9]+)?$'
FIND='/usr/bin/env find'
IMAGES="centos-7.6-x86_64
ubuntu-18.04-amd64"
BUILDERS="virtualbox-iso"

echo "Please enter your GitHub personal access token (we don't save it):"
read -s TOKEN

LATEST_TAG=$($CURL -s https://api.github.com/repos/librenms/librenms/releases/latest | $JQ -r ".tag_name")

if ! [[ "$LATEST_TAG" =~ $RE ]] ; then
    echo "Tag not found"; exit 1;
fi

echo "Creating new release $LATEST_TAG"

UPLOAD_URL=$($CURL -s https://api.github.com/repos/librenms/packer-builds/releases -H "Authorization: token $TOKEN" -X POST --header "Content-Type: application/json" -d "{\"tag_name\":\"$LATEST_TAG\",\"name\":\"v$LATEST_TAG\"}" | $JQ -r ".upload_url")
UPLOAD_URL="${UPLOAD_URL//\{\?name,label\}/}"
FILES=$($FIND ./output-* -type f -print)
for FILE in $FILES; do
    IFS='/' read -a OVA <<< "$FILE"
    NAME=${OVA[2]}
    echo "$CURL -s \"$UPLOAD_URL?name=$NAME\" -H \"Authorization: token <TOKEN>\" -T \"$FILE\" -X POST -H \"Content-Type: application/tar\""
    UPLOAD=$($CURL -s "$UPLOAD_URL?name=$NAME" -H "Authorization: token $TOKEN" -T "$FILE" -X POST -H "Content-Type: application/tar")
    if [ $? != 0 ] ; then
        echo "Upload failed:"
        echo $UPLOAD
    else
        echo "Upload completed"
    fi
done
