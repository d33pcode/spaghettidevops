+++
date = "2017-04-10T09:57:36+02:00"
title = "Pattern matching in c, reinventing the wheel"
author = "bamless"
type = "post"
tags = ["programming", "regex", "regular", "expressions", "c"]
draft = true
+++

The other day i was bored, and I don't know what normal people do when they are bored, but i usually do one thing... code. Actually it all starts with me wondering about some problem, a random problem, then thinking about a solution in my head, and it ends with me implementing it in a random programming language. It all started this way with this little program. I was thinking about how often i use regular expressions every day on my Linux installation, without really knowing how they work. So i decided to get my hands dirty and implement a pattern matching algorithm in c. Now, you might be thinking: "What the hell? the c standard library already provides regex matching algorithms, what are you doing?". As stated in the title, I'm reinventing the wheel. Why am i doing this? Well, apart from boredom, I'm doing this for knowledge's sake. The best way to fully understand something (in the CS world), is to implement it.

### What the hell is a regular expression

According to wikipedia:

> A regular expression, regex or regexp (sometimes called a rational expression) is, in theoretical computer science and formal language theory, a sequence of characters that define a search pattern. Usually this pattern is then used by string searching algorithms for "find" or "find and replace" operations on strings.

A regular expression can be as simple as a sequence of literals, for example the regex `app` will match every string that contains the string `app`, such as `application`, `applicative`, etc...

It can also contain special operators, such as the *kleene star* `*`, that matches the previous character zero or more times, or the `+` that matches the previous character 1 or more times. for example the *regex* `abc*def` matches `abdef`, `abcdef`, `abccdef`, `abcccdef`... and so on.

Regexs can contain a wildcard, a special character that will match with any other character. Usually this special char is denoted with `.` (a point).

Two other special operators are the "anchor" operators `^` and `$`. The first can be used only at the beginning of a regex, and will match the following pattern only at the beginning of a string. As an example, `^app` will match `application` but not `an anpplication`. The `$` is very similar, but can be used only at the end of a regex and will match the pattern only at the end of a string.

Regexs can also support other operators, such as the `|` or operator, or the "backreference" operator (even though a regex with backreferences is not strictly speaking a regex, because can recognize non [regular languages](https://en.wikipedia.org/wiki/Regular_language)). For a full overview of regular expressions see: https://en.wikipedia.org/wiki/Regular_expression.

In this article, for simplicity, we're going to implement only the wildcard, `^`, `$`, `*`, `+` and `?` operator (that last one matches the prev char 0 or 1 time) and we won't support parenthesis.

### Let's start coding

As already mentioned we're going to implement the regex matcher in c. The algorithm proceeds by backtracking on the `*`, `?` and `+` operators, so it is not the most efficient, but it turns out to be pretty simple and to perform well most of the times. At the end of the article we're going to discuss its complexity and we'll look at more efficient algorithms.

Let's start by creating an header file:
```
#ifndef __REGEX_H__
#define __REGEX_H__

int match_regex(const char *regex, const char *word);

#endif //__REGEX_H__
```
as you can see the function is very simple.
