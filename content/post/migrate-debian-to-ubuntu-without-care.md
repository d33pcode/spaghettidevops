+++

type = "post"
title = "Migrate Debian to Ubuntu without care"
draft = false
author = "streambinder"
date = "2017-04-10T21:39:00+01:00"
tags = ["sysadmin", "bash", "debootstrap", "debian", "squeeze", "ubuntu", "xenial xerus"]

+++

Let's start the game.

Assume you have - boss obligation - to migrate thousand terminals from *Debian* to *Ubuntu*. From *Squeeze* to *Xenial Xerus*.
If I'm not wrong, *Xenial Xerus* got release on April 2016. On the other hand, the good old *Squeeze* - older than good -, on February 2011. Actually it represents my first *Debian* powered environment (yup, I'm just a teenager).

Between 2011 and 2016 lots of things happened and changed, but do not digress: you have to make a migration.
This activity is parameterized by the fact you cannot actively touch **any** of these devices. You have to make something working so good you just have to run it and it will make any *Squeeze*-powered device boot into a *Xenial Xerus* one, just with a reboot (it's a not **a** *Xenial Xerus*, but **that** specific one with **that** specific package versions). Oh, and if it fails, you want a least to come back safe on the *Squeeze* one.

After some quick researches online (*online* is so 00s - or 2000s, dunno how to write it), found a really useful tool: *debootstrap*.
It's a *bash*-written software available in any *deb*-based distribution that owes its existence to a sysadmin like me, stuck in my same situation.
This software actually reimplement any basilar *deb* repository system interaction type in *bash* just with the aim of deploying a basilar *Debian* (or *deb*-based) system, just indicating its name (associated with a special manifest that specifies any particularity of itself) and a repository to get the things from.

It seems that it solves my whole problem. Actually not. It's not that easy.
There're many things to take care of: if you want to rebase every part of the *Debian*-powered environment into the *Ubuntu* one, you need to find a way to replicate lot of parts, such as the network (even VPN?) configuration, users and groups one, and so on. Also, keep in mind that *debootstrap* doesn't configure an actually usable environment: it just does its best to prepare it to let you easily be able to interact with its base functions, such as the package manager system (yes, this thing solves thousands of problems). But this means also that you're missing of kernel and, that way, of any kind of bootloader.

So, let's proceed per steps.

### Getting ready

Let's start with preparing the source environment to do the effective migration:

1. update the system, it's always good
2. install *debootstrap* package (it's called exactly that way)
3. now I suggest to overlap stock *debian*'s *debootstrap* version with *ubuntu*'s updated one, that will contains its updated releases manifests. To do that, let's head to the [*ubuntu* package repository](http://packages.ubuntu.com), search *debootstrap* package and download it (both via *wget* or via web-gui)

### Launching the (de)bootstrap process

Doing the effective bootstrap is actually very simple:

```bash
debootstrap --arch i386 xenial /target/mount/point http://archive.ubuntu.com/ubuntu/
```

The `/target/mount/point` is intended to be the path where you actually mounted the partition to deploy the *ubuntu* release on.
Obviously the `arch` flag is needed only if you want to deploy an architecture different from the one you're currently on.

#### The mirror

In the example above I used `http://archive.ubuntu.com/ubuntu/` as mirror. You can actually use every mirror you want, even a local one.
In this case, though, you need to apply a patch (actually in the real scenario, I needed to deploy an *ubuntu* using a local - as *on filesystem* - repository, dynamically recreated during the migration process: this node brought me to discover few bugs on *debootstrap*) and also do some hacking on the `Packages` index file, to hide the `:[1-9]` annotation on packages names. For more about that: [*debubupdater*](https://github.com/streambinder/debubupdater). The syntax would be:

```bash
debootstrap xenial /target/mount/point file:///path/to/repository
```

##### Notes about error management on *debootstrap*

Just a note: *debootstrap* doesn't help you in any way if anything goes wrong, so keep in mind that it will have correctly deployed the system only if it finally tells you something like `Minimal system correctly installed`. In any other case, something made it fail and you'll probably have to look at the `functions` (in my case it was in `/usr/share/debootstrap/functions`) and do some manual debug, as I actually did.

### Make *Ubuntu* bootable

Now that you have a minimal *ubuntu* release correctly deployed, you'll need to make it bootable.
In order to get inside the new installation, we'll use `chroot`, that will set the target mountpoint as our root:

```bash
chroot /target/mount/point /bin/bash
```

Let's select whatever to install:

1. Fundamental: `kernel`. To install `kernel`, you'll need something like that:

```bash
apt install linux-headers-generic linux-image-generic
```

2. Fundamental: `grub`:

```bash
apt install grub2
```

3. Not that fundamental, but you'll likely want to install some base packages that aren't included by default. To do that I used to install the `server` group packages, with the following syntax:

```bash
apt install server^
```

I don't exclude the case you want install something else/different: look at the [tasksel groups](https://wiki.debian.org/it/tasksel) to find out what do install.

4. Really not needed, but useful if it's all about servers in your scenarios, too. Let's install `ssh`:

```bash
apt install openssh server
sed -i "/^PermitRootLogin/c PermitRootLogin yes" /etc/ssh/sshd_config
service sshd reload
```

5. As you're never too careful, let's assure `grub` correctly detected our new partition and installed that as new entry:

```bash
grub-install /dev/sda
grub-install --recheck /dev/sda
update-grub2
```

### Final considerations
This post has been written to make some sum-ups considered useful after living my adventure summarized in the code available on [my github](https://github.com/streambinder/debubupdater), and therefore it just underlines few important steps about what the procedure actually is (or just has been in my real case). I do not expect this will solve any problem you could encounter while trying to similarly make such migrations, but at least I hope it will help you.
