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
as you can see the function is very simple. We're going to take 2 pointers to char as input: one to the regex, the other to the string we want to match.
```
int match_regex(const char *regex, const char *word) {
    do {
        if(match(regex, word))
            return 1;
    } while(*word++ != '\0');
    return 0;
}
```
This is the code of the function. As you can see it tries to match the string via the *match* function, incrementing the string pointer by one at every iteration. We can then add support for the `^` operator just by adding a few lines to the top:
```
int match_regex(const char *regex, const char *word) {
    //if the first char is ^, then try to match only 1 time, at the beginning of the string
    if(*regex == '^')
        return match(regex + 1, word);
    //else try to match multiple times, starting each time from a different position
    do {
        if(match(regex, word))
            return 1;
    } while(*word++ != '\0');
    return 0;
}
```
Let's now take a look at the hearth of the algorithm, the *match* function. We're going to start easy by adding only the portion of code that checks if the current literal matches the current position in the regex, and then we'll expand the function, adding the various cases for all the operators.
```
static int match(const char *regex, const char *word) {
    if(*regex == '\0') return 1;
    if(*word != '\0' && *regex == *word)
        return match(regex + 1, word + 1);
    return 0;
}
```
For now, the code is pretty straightforward. In the first line of the function we're going to check if we've reached the end of the regex (the recursion base case). If we have, it means we've found a match, otherwise the function would have returned 0 at some point instead of proceeding with the recursion. The second line is the one that actually checks the match and proceed with the recursion. it checks if the string we're trying to match isn't finished and if the current literal of the regex matches the current literal of the string. If the conditions are met, it increments the regex and word pointers - in other words it shifts the current char of the regex and word by one to the right - and it calls recursively itself. As it is, this function implements a very convoluted way to check two string for equality, now we need to implement the various regex operators.
```
static int match(const char *regex, const char *word) {
    if(*regex == '\0') return 1;
    if(*regex != '\\') {
        if(regex[1] == '*')
            return match_star(regex,  word);
        if(regex[1] == '+')
            return match_plus(regex, word);
        if(regex[1] == '?')
            return match_question(regex, word);
        if(*regex == '$' && regex[1] == '\0')
            return *word == '\0';
        if(*word != '\0' && *regex == '.')
            return match(regex + 1, word + 1);
    } else {
        regex++;
    }
    if(*word != '\0' && *regex == *word)
        return match(regex + 1, word + 1);
    return 0;
}
```
This is the function that supports all the operators. The second _if_ checks for the escape character, and, if found, skips the operator checking stage and proceeds with the literal match. The operator checking section is pretty simple, it defines a series of cases, and it calls the appropriate function for each one. Let's examine the cases one by one: <br/>
- The first case checks for the `*` operator. If it finds the "\*" character in the next string position it calls the *match_star* function:
```
static int match_star(const char *regex, const char *word) {
    char match_char = *regex;
    regex += 2;
    do {
        if(match(regex, word))
            return 1;
    } while(*word != '\0' && (match_char == *word++ || match_char == '.'));
    return 0;
}
```
The *match_star* function is pretty simple and does exactly what you would expect. It tries, with a *do while* loop, to match the string 0 or more times by calling repeatedly the *match* function until it returns true, or until the current position of the string does not match anymore with the character before the \* operator. Naturally, at every iteration we need to increment the string current position, otherwise the loop won't terminate. This is done, perhaps in a cryptic way, directly in the while condition to save space. For this very reason, the `match_char == *word++` condition *must* appear before the `match_char == '.'` condition, otherwise we are not guaranteed that the pointer will be incremented.  
