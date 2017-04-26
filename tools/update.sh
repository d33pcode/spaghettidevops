#!/bin/sh

set -e

PATH_GIT="$(dirname $(readlink -f -- "$0"))/.."
PATH_WEB="$1"

if [[ -z ${PATH_GIT} ]] || [[ -z ${PATH_WEB} ]]; then
 echo "Needed paths not given."
 exit 1
fi

cd ${PATH_GIT}
git remote update
if [ $(git status -uno | grep behind | wc -l) -gt 0 ]; then
 rm -rf public
 git pull
 hugo
 find "${PATH_WEB}" -exec rm -rf {} \;
 rsync -av --delete public/ "${PATH_WEB}/"
 cd "${PATH_WEB}"
 /usr/bin/css-html-js-minify.py --overwrite .
 chown -R "$(ls -ld "${PATH_WEB}" | awk '{print $3":"$4}')" "${PATH_WEB}"
fi
