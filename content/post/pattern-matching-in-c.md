+++
date = "2017-04-21T18:33:36+02:00"
title = "Pattern matching in c, reinventing the wheel"
author = "bamless"
type = "post"
tags = ["programming", "regex", "regular", "expressions", "c"]
draft = false
+++

The other day I was bored, and I don't know what normal people do when they are bored, but I usually do one thing... code. Actually it all starts with me wondering about some problem, a random problem, then thinking about a solution in my head, and it ends with me implementing it in a random programming language. It all started this way with this little program. I was thinking about how often I use regular expressions every day on my Linux installation, without really knowing how they work. So I decided to get my hands dirty and implement a pattern matching algorithm in c. Now, you might be thinking: "What the hell? the c standard library already provides regex matching algorithms, what are you doing?". As stated in the title, I'm reinventing the wheel. Why am I doing this? Well, apart from boredom, I'm doing this for knowledge's sake. The best way to fully understand something (in the CS world), is to implement it.

### What the hell is a regular expression

According to wikipedia:

> A regular expression, regex or regexp (sometimes called a rational expression) is, in theoretical computer science and formal language theory, a sequence of characters that define a search pattern. Usually this pattern is then used by string searching algorithms for "find" or "find and replace" operations on strings.

A regular expression can be as simple as a sequence of literals, for example the regex `app` will match every string that contains the string `app`, such as `application`, `applicative`, etc...

It can also contain special operators, such as the *kleene star* `*`, that matches the previous character zero or more times, or the `+` that matches the previous character 1 or more times. For example the *regex* `abc*def` matches `abdef`, `abcdef`, `abccdef`, `abcccdef`... and so on.

Regexs can contain a wildcard, a special character that will match with any other character. Usually this special char is denoted with `.` (a point).

Two other special operators are the "anchor" operators `^` and `$`. The first can be used only at the beginning of a regex, and will match the following pattern only at the beginning of a string. As an example, `^app` will match `application` but not `an application`. The `$` is very similar, but can be used only at the end of a regex and will match the pattern only at the end of a string.

Regexs can also support other operators, such as the `|` or operator, or the "backreference" operator (even though a regex with backreferences is not strictly speaking a regex, because can recognize non [regular languages](https://en.wikipedia.org/wiki/Regular_language)). For a full overview of regular expressions see: [regular expressions - Wikipedia](https://en.wikipedia.org/wiki/Regular_expression).

In this article, for simplicity, we're going to implement only the wildcard, `^`, `$`, `*`, `+` and `?` operator (that last one matches the previous char 0 or 1 time) and we won't support parenthesis.

### Let's start coding

As already mentioned we're going to implement the regex matcher in c. The algorithm proceeds by backtracking on the `*`, `?` and `+` operators, so it is not the most efficient, but it turns out to be pretty simple and to perform well most of the times. At the end of the article we're going to discuss its complexity and we'll look at more efficient algorithms.

One more thing: this is not a c tutorial, so I'm going to assume you have at least a basic understanding of how c works, especially pointers and strings.

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
For now, the code is pretty straightforward. In the first line of the function we're checking if we've reached the end of the regex (the recursion base case). If we have, it means we've found a match, otherwise the function would have returned zero at some previous point in the execution. The second line is the one that actually checks the match and proceeds with the recursion. It checks if the string we're trying to match isn't finished and if the current literal of the regex matches the current literal of the string. If the conditions are met, it increments the regex and word pointers - in other words it shifts the current char of the regex and word by one to the right - and it calls recursively itself. As it is, this function implements only a very convoluted way to check two string for equality. To match regular expressions, we need to implement the cases for regex operators:
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
This is the function that supports all the operators. The second *if* checks for the escape character, and, if found, skips the operator checking stage and proceeds with the literal match. The operator checking section is pretty simple, it defines a series of cases, and it calls the appropriate function for each one. Let's examine the cases one by one:

- The first case checks for the `*` operator. If it finds the "\*" character in the next regex position it calls the *match_star* function:
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
The *match_star* function does exactly what you would expect. It tries, with a *do while* loop, to match the string 0 or more times by calling repeatedly the *match* function until it returns true, or until the current position of the string does not match anymore with the character before the \* operator. Naturally, at every iteration we need to increment the string current position, otherwise the loop won't terminate. This is done, perhaps in a cryptic way, directly in the while condition to save space. For this reason, the `match_char == *word++` condition *must* appear before the `match_char == '.'` condition, otherwise we are not guaranteed that the pointer will be incremented.

- The second case checks for the `+` operator. Exactly like the first case, if the next character in the regex is equal to the operator char it calls the specific function to handle it:
```
static int match_plus(const char *regex, const char *word) {
        char match_char = *regex;
        regex += 2;
        while(*word != '\0' && (match_char == *word++ || match_char == '.')) {
            if(match(regex, word))
                return 1;
        }
        return 0;
}
```
As you can see, this function is exactly the same as the previous one, with the only difference being the use of the *while* instead of the *do while* loop. This means that the code inside the loop can't be executed if the conditions are not met, not even once. This produces the effect of the "+" operator, that matches the previous character **one** or more times.

- The third case, is very similar to the other ones. It calls this function when it finds the "?" character in the regex:
```
static int match_question(const char *regex, const char *word) {
        char match_char = *regex;
        regex += 2;
        if(match(regex, word))
            return 1;
        if(word != '\0' && (match_char == *word || match_char == '.'))
            return match(regex, word + 1);
        return 0;
}
```
As you can see, instead of a loop this time we have only two conditional statements, one tries to match without incrementing nor the regex nor the string, and the other tries to match the next char in the string with the current char in the regex. This will match the previous char to "?" 0 or 1 times, exactly as the `?` operator should do.
- The fourth case is a little different, as it checks for the second "anchor" operator `$`. This is perhaps the simplest check:
```
if(*regex == '$' && regex[1] == '\0')
        return *word == '\0';
```
If we are located on the last character of the regex, and that character is "$", then the only thing we need to check is if we are located at the end of the word string too. In fact, if we are, then we have matched the regex on the end of the string.
- I lied in the previous point. This is the simplest case:
```
if(*word != '\0' && *regex == '.')
        return match(regex + 1, word + 1);
```
if we encounter the wildcard then we're going to match every character and proceed with the recursion.

Well, that was a fair bit of code... I hope that the algorithm's operation is clear to you by now. If not, then go back and give it another read, because you'll need a good understanding of the code for the next sections, in which we will discuss the algorithm's complexity and other alternatives.

### Welcome to computational complexity 101

In the previous paragraph we've looked at the implementation of a regex matching algorithm.
As you've seen the code is not that complicated (if you understand recursion) and it is pretty short. The regex gets interpreted on the fly and the algorithm proceeds by backtracking on the `*` and `+` operators. Unfortunately simplicity of the code does not imply efficiency. In fact, the backtracking part of the algorithm hides an exponential worst-case complexity behind recursion and average case running times. Even if the algorithm is pretty fast for the most common combinations of regex/string we can construct "pathological" regex/string combinations that will force the backtracking algorithm to explore all the solution space. One such combination is `.*.*.*.*.*.*1`, `0000000000000`. In this case the algorithm will try to match the `*` operator multiple times, trying all the combinations and failing each time. We can easily prove that this process takes exponential time. Let's examine the worst case in which the algorithm enters every time the *match_star* function except for the last iteration: at iteration $i$, the *match_star* function calls itself over input $n - i$. The function does, in the worst case, $n$ iterations. So we have the recurrence equation:
\\[t(n)=\begin{cases} 1 & \mbox{if }n\mbox{ is zero} \\\ t(n-1) + t(n-2) + ... + t(1) + 1 & \mbox{otherwise} \end{cases}\\]
Let's work out a few of the terms of the recurrence:
\\[t(1) = 1 \mathbin{,\ } t(2) = t(1) + 1 = 2 \mathbin{,\ }\\]
\\[t(3) = t(2) + t(1) + 1 = 4 \mathbin{,\ } t(4) = t(3) + t(2) + t(1) + 1 = 8\\]
It seems pretty evident that $\mathbin{\ }t(i) = 2^{i -1}$, we can prove it by induction:

**basis** \
Let's show that the statement holds for $n = 1$. We have $\mathbin{\ }t(1)=1=2^{0}$, so the statement is true for $n = 1$.

**inductive step** \
Assuming $t(n) = 2^{n-1}$, show that $t(n+1) = 2^{n}$:
\\[t(n+1) = t(n) + t(n-1) + t(n-2) + t(n-3) + ... + t(1) +1\\]
we can easily see that, aside from the first term, the recurrence equation is the same as before, so we can substitute:
$$t(n + 1)= t(n) + t(n) = 2^{n-1} + 2^{n-1} = 2^{n}$$

So we can conclude that $\mathbin{\ }t(n) \in O(2^{n})$. Since every other case takes the same or less amount of time as the `*` case, we have a worst case upper bound.

### Can we do better?

Yeah, we can, and it turns out that a lot of implementations already do. A first idea to boost performance is to use *memoization*. If we trace out an execution tree of the execution of the algorithm we can easily see that we incur in the recalculation of a lot of sub-problems. Implementing a memoization table to cache the results can bring a big improvement especially on "pathological" instances. This approach is certainly a valid one, but it turns out that we can do even better. Meet the [NFA](https://en.wikipedia.org/wiki/Nondeterministic_finite_automaton). It actually turns out that NFAs and regural expressions are equivalent, so we can easily convert one in the other, and we can do this in linear time. Then, thanks to other computational theory magic we can convert the NFA to a plain old [DFA](https://en.wikipedia.org/wiki/Deterministic_finite_automaton) in exponential time. The catch is that, besides the one-time exponential time compilation, we can run every string on the DFA in linear time how many times we want. All this converting from automaton to automaton would certainly require a compilation step, and the simultation and construction of a DFA will increase a fair bit the complexity of the code, but the linear time complexity is definitely worth the effort. I'm not going to implement this algorithm, in part because I'm lazy, and in part because I found this awesome article that already does it very well: [article](http://www.diku.dk/hjemmesider/ansatte/henglein/papers/cox2007.pdf).

### Conclusions

So what's the moral of the story?

The moral is that you can spend a lot of time implementing a inefficient algorithm (that is already implemented) and even more time writing an article about it, so maybe it is better to just do something else. That, or the fact that sometimes reinventing the wheel can push you to really understand a problem, and maybe gain little insights in previously obscure parts of CS, all while having fun. I'll let you decide which one.

Here's the link to the code: [pattern-matching](/res/pattern-matching-in-c/regex.tar.bz2).
