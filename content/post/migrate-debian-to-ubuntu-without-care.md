+++

type = "post"
title = "Migrate Debian to Ubuntu without care"
draft = true
author = "streambinder"
date = "2017-04-09T21:39:00+01:00"
tags = ["sysadmin", "bash", "debootstrap", "debian", "squeeze", "ubuntu" "xenial xerus"]

+++

Let's start the game.

Assume you have - boss obligation - to migrate thousand terminals from *Debian* to *Ubuntu*. From *Squeeze* to *Xenial Xerus*.
If I'm not wrong, *Xenial Xerus* got release on April 2016. On the other hand, the good old *Squeeze* - older than good -, on February 2011. Actually it represents my first *Debian* powered environment (yup, I'm just a teenager).

Between 2011 and 2016 lots of things happened and changed, but do not digress: you have to make a migration.
This activity is parameterized by the fact you cannot actively touch **any** of these devices. You have to make something working so good you just have to run it and it will make any *Squeeze*-powered device boot into a *Xenial Xerus* one, just with a reboot (it's a not **a** *Xenial Xerus*, but **that** specific one with **that** specific package versions). Oh, and if it fails, you want a least to come back safe on the *Squeeze* one.

After some quick researches online (*online* is so 00s - or 2000s, dunno how to write it), found a really useful tool: *debootstrap*.
It's a *bash*-written software available in any *deb*-based distribution that owes its existence to a sysadmin like me, stuck in my same situation.
This software actually reimplement any basilar *deb* repository system interaction type in *bash* just with the aim of deploying a basilar *Debian* (or *deb*-based) system, just indicating its name (associated with a special manifest that specifies any particularity of itself) and a repository to get the things from.

It seems I could use that one and I'm ok. Actually not. It's not that easy.
There're many things to take care of: if you want to rebase every part of the *Debian*-powered environment into the *Ubuntu* one, you need to find a way to replicate lot of parts, such as the network (even VPN?) configuration, users and groups one, and so on. Also, if you want
