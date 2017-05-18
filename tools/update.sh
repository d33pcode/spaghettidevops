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
 rsync -av --delete public/ "${PATH_WEB}/"
 if which css-html-js-minify.py; then
  css-html-js-minify.py --overwrite  "${PATH_WEB}"
 fi
 chown -R "$(ls -ld "${PATH_WEB}" | awk '{print $3":"$4}')" "${PATH_WEB}"
fi
