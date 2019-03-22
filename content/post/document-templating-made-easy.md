+++

author = "streambinder"
date = "2019-03-21T15:03:00+02:00"
description = "Document templating made easy"
draft = false
keywords = []
tags = ["sysadmin", "mustache", "bash", "script", "latex"]
title = "Document templating made easy"
topics = []
type = "post"

+++


Everyone has his own CV. CV is a fundamental asset to move in the world of work.
And I have mine, so nothing wrong till now.
I'm using a git repository to host its sources, as it's written in LaTeX, and keeping every version using a dedicated repository release.
Still, no problem till now.

One day, a friend of mine told me about the issue of having a hipster-like CV, without providing any universally approved version. Problem one: some companies actually require a specific CV format in order to consider it. I need to find a way to support multiple templates without duplicating the documents to maintain, as I actually wanna keep my hipster-like one.

I have a double copy of the `tex` file: the first one is written in Italian, and the latter, in English.
Problem two: I need to find a way to support multiple languages without, again, duplicating the documents to maintain.

The problem is really simple, then: I need to find a way to handle multiple document output formats - both for languages and templates issues - using a common database to populate them.

The snippets and hints you find below represent the home-made solution to this problem.

## Internationalization

In order to handle the languages differentiation, I opted for the use of a single JSON file, in which to associate a single keyword to multiple translated values. Something like this:

```json
{
   "keyword": {
       "it": "valore",
       "en": "value"
   },
   ...
}
```

As my aim is to provide, looping over languages, the specific keyword value matching that specific language, let's provide the way I do that:

```bash
jq -r 'to_entries[] | "\(.key) \(.value.it)"' < keys.json
```

As you can see, `jq` command is being used. It's a powerful shell tool to handle and manipulate JSON objects data. That snippet will print something like this:

```bash
keyword valore
...
```

As you may want to automagically loop over every language our JSON is offering translations for, here you have a simple snippet extension:

```bash
jq -r 'first(.[] | keys | @csv)' < keys.json | sed 's/,/ /g' | xargs | while read lang; do
   echo "Keywords for ${lang} language:"
   jq -r --arg lang "${lang}" 'to_entries[] | "\(.key)=\(.value[$lang])"' < keys.json
done
```

## Templating documents

The second part was about applying specific data into generic documents field. I found out a useful tool called `mush` ([jwerle/mush](https://github.com/jwerle/mush)) which overrides those ones with the values of the corresponding environment keys.
Its use is pretty straightforward. Suppose we need to apply several `name` values in the same template document, if you use the following snippet:

```bash
for name in "streambinder" "bamless" "d33pcode" do;
   cat <<EOF
Hey, my name is {{name}}!
EOF | name=${name} mush > document.${name}.txt
done
```

You'll get something like this:

```bash
Hey, my name is streambinder!
Hey, my name is bamless!
Hey, my name is d33pcode!
```

## Merging the two concepts

If we merge the use we do of `mush` and `jq` over several LaTeX documents, we'll get something like this:

```bash
for tex_variant in *.tex; do
   tex_basename="$(sed 's/.tex//g' <<< "${tex_variant}")"
   for lang in $(jq -r 'first(.[] | keys | @csv)' < keys.json | sed 's/,/ /g' | xargs); do
       echo "Building $tex_variant in for $lang language..."
       while read -r var; do
           key="$(awk -F'=' '{print $1}' <<< "${var}")"
           value="$(cut -d"=" -f2- <<< "${var}")"
           value_cmd="$(awk '{print $1}' <<< "${value}")"
           if (which "${value_cmd}" && eval "${value}") > /dev/null 2>&1; then
               export $key="$(eval $value)"
           else
               export $key="$value"
           fi
       done <<< "$(jq -r --arg lang "$lang" -r 'to_entries[] | "\(.key\)=\(.value[$lang]\)"' < keys.json)"
       tex_lang_variant="${tex_basename}.${lang}.tex"
       mush < "${tex_variant}" > "${tex_lang_variant}" && \
       pdflatex -synctex=1 -interaction=nonstopmode -output-directory=../bin "${tex_lang_variant}" 2>&1 > /dev/null && \
       rm -f "${tex_lang_variant}"
   done
done
```

