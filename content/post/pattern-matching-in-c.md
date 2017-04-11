+++
date = "2017-04-10T09:57:36+02:00"
title = "Pattern matching in c, reinventing the wheel"
author = "bamless"
type = "post"
tags = ["programming", "regex", "regular", "expressions", "c"]
draft = true
+++

The other day i was bored, and I don't know what normal people do when they are bored, but i usually do one thing... code. Actually it all starts with me wondering about some problem, a random problem, then thinking about a solution in my head, and it ends with me implementing it in a random programming language. It all started this way with this little program. I was thinking about how often i use regular expressions every day on my Linux installation, without really knowing how they work. So i decided to get my hands dirty and implement a pattern matching algorithm in c, just to get a better idea of how it all works.

### What the hell is a regular expression

According to wikipedia:

> A regular expression, regex or regexp (sometimes called a rational expression) is, in theoretical computer science and formal language theory, a sequence of characters that define a search pattern. Usually this pattern is then used by string searching algorithms for "find" or "find and replace" operations on strings.

A regular expression can be as simple as a sequence of literals, for example the regex `app` will match every string that contains the string `app`, such as `application`, `applicative`, etc...

It can also contain special operators, such as the *kleene star* `*`, that matches the previous character zero or more times, or the `+` that matches the previous character 1 or more times. for example the *regex* `abc*def` matches `abdef`, `abcdef`, `abccdef`, `abcccdef`... and so on.

Regexs can also contain a wildcard, a special character that will match with any other character. Usually this special char is denoted with `.` (a point).

In this article, for simplicity, we're going to implement only the wildcard, `*`, `+` and `?` operator (that last one matches the prev char 0 or 1 time) and we won't support parenthesis.
