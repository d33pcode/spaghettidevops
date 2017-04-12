+++

type = "post"
title = "Migrate Debian to Ubuntu without care"
draft = false
author = "streambinder"
date = "2017-04-10T21:39:00+01:00"
tags = ["sysadmin", "bash", "debootstrap", "debian", "squeeze", "ubuntu", "xenial xerus"]

+++

Let's start the game.

Assume you have - boss obligation - to migrate thousand terminals from _Debian_ to _Ubuntu_. From _Squeeze_ to _Xenial Xerus_. If I'm not wrong, _Xenial Xerus_ got release on April 2016\. On the other hand, the good old _Squeeze_ - older than good -, on February 2011\. Actually it represents my first _Debian_ powered environment (yup, I'm just a teenager).

Between 2011 and 2016 lots of things happened and changed, but do not digress: you have to make a migration. This activity is parameterized by the fact you cannot actively touch **any** of these devices. You have to make something working so good you just have to run it and it will make any _Squeeze_-powered device boot into a _Xenial Xerus_ one, just with a reboot (it's a not **a** _Xenial Xerus_, but **that** specific one with **that** specific package versions). Oh, and if it fails, you want a least to come back safe on the _Squeeze_ one.

After some quick researches online (_online_ is so 00s - or 2000s, dunno how to write it), found a really useful tool: _debootstrap_. It's a _bash_-written software available in any _deb_-based distribution that owes its existence to a sysadmin like me, stuck in my same situation. This software actually reimplement any basilar _deb_ repository system interaction type in _bash_ just with the aim of deploying a basilar _Debian_ (or _deb_-based) system, just indicating its name (associated with a special manifest that specifies any particularity of itself) and a repository to get the things from.

It seems that it solves my whole problem. Actually not. It's not that easy. There're many things to take care of: if you want to rebase every part of the _Debian_-powered environment into the _Ubuntu_ one, you need to find a way to replicate lot of parts, such as the network (even VPN?) configuration, users and groups one, and so on. Also, keep in mind that _debootstrap_ doesn't configure an actually usable environment: it just does its best to prepare it to let you easily be able to interact with its base functions, such as the package manager system (yes, this thing solves thousands of problems). But this means also that you're missing of kernel and, that way, of any kind of bootloader.

So, let's proceed per steps.

# Getting ready

Let's start with preparing the source environment to do the effective migration:

1. update the system, it's always good
2. install _debootstrap_ package (it's called exactly that way)
3. now I suggest to overlap stock _debian_'s _debootstrap_ version with _ubuntu_'s updated one, that will contains its updated releases manifests. To do that, let's head to the [_ubuntu_ package repository](http://packages.ubuntu.com), search _debootstrap_ package and download it (both via _wget_ or via web-gui)

# Launching the (de)bootstrap process

Doing the effective bootstrap is actually very simple:

```bash
debootstrap --arch i386 xenial /target/mount/point http://archive.ubuntu.com/ubuntu/
```

The `/target/mount/point` is intended to be the path where you actually mounted the partition to deploy the _ubuntu_ release on. Obviously the `arch` flag is needed only if you want to deploy an architecture different from the one you're currently on.

## The mirror

In the example above I used `http://archive.ubuntu.com/ubuntu/` as mirror. You can actually use every mirror you want, even a local one. In this case, though, you need to apply a patch (actually in the real scenario, I needed to deploy an _ubuntu_ using a local repository built on the filesystem, dynamically recreated during the migration process: this node brought me to discover few bugs on _debootstrap_) and also do some hacking on the `Packages` index file, to hide the `:[1-9]` annotation on packages names.

- it seems that - at least on `1.0.78` version - _debootstrap_ cannot easily handle local repositories. In fact, it encounters some problems while trying to aggregate informations between the repository path, the internal gerarchical repository paths and the packages filenames. In order to get out from this situation, a simple `sed` command should be enough:

  ```bash
  line_n=$(grep -n 'pkgs_to_get="$(download_debs "$m" "$pkgdest" $pkgs_to_get 5>&1 1>&6)' /usr/share/debootstrap/functions | awk -F':' '{ print $1 }')
  sed -i.orig "${line_n}s/\$m/\$m\/dists\/\$SUITE\/\$c\/binary\-\$ARCH/" /usr/share/debootstrap/functions
  ```

  It could seem difficult, but actually it does a very simple procedure: it will be looking for the string `pkgs_to_get="$(download_debs "$m" "$pkgdest" $pkgs_to_get 5>&1 1>&6)` and will replace it with `pkgs_to_get="$(download_debs "$m/dists/$SUITE/$c/binary-$ARCH" "$pkgdest" $pkgs_to_get 5>&1 1>&6)`.

- also, during the effective packages deploy directed by _debootstrap_, it correctly manage to move packages from the repository on the target partition, but it's unable to install them. This is just due to the fact that in packages filenames often compares a `:N` annotation. This is used by _debian_ package manager to indicate a local package manager version increase, that actually brings the same package version itself. Even if you fetched all the packages without the annotation, while building the local repository with the `apt-ftparchive packages . > Packages` command, the `Packages` index file will be populated with them (as the information is contained inside the package itself). So, more tricky than the previous patch but perfectly working, before launching the _debootstrap_ process, we'll need to make some hacks on our `Packages` index:

  ```bash
  line_n=0; cat Packages | while read line; do
      line_n=$(($line_n + 1))
      if [[ $(echo ${line} | grep '^Version:' | wc -l) -gt 0 ]] && [[ $(echo ${line} | awk -F':' '{ print $3 }') != "" ]]; then
        sed -i "${line_n}s/.*/Version\:\ $(echo ${line} | awk -F':' '{ print $3 }')/" Packages
      fi
    done
  ```

  This way, we'll have removed for all the packages specifications contained in the `Packages` index the `:N` annotation. **NB** This is only needed by _debootstrap_, if you need to interact with your local repository even after the _debootstrap_'s job, you need to restore the `Packages` index by re-triggering the build with `apt-ftparchive packages . > Packages`.

In any case, in order to use a local repository rather than the official remote one, the syntax would be:

```bash
debootstrap xenial /target/mount/point file:///path/to/repository
```

### Error management on debootstrap

Just a note: _debootstrap_ doesn't help you in any way if anything goes wrong, so keep in mind that it will have correctly deployed the system only if it finally tells you something like `Minimal system correctly installed`. In any other case, something made it fail and you'll probably have to look at the `functions` (in my case it was in `/usr/share/debootstrap/functions`) and do some manual debug, as I actually needed to.

# Make Ubuntu bootable

Now that you have a minimal _ubuntu_ release correctly deployed, you'll need to make it bootable. In order to get inside the new installation, we'll use `chroot`, that will set the target mountpoint as our root:

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

## Need to replicate something else?

The following part of the article will contains just few code snippets to replicate _debian_ configuration to _ubuntu_.

### `fstab` configuration

As anyone knows, without a correct `fstab` configuration, system will unable to boot. This is why this script is absolutely needed. Actually it will copy `swap` and `/proc` _debian_ configurations, and then will generate `/boot` and `/` ones.

```bash
cp -fp ${MOUNTPOINT}/etc/fstab{,.old}
cat /etc/fstab | awk '/\/proc/' > ${MOUNTPOINT}/etc/fstab
cat /etc/fstab | awk '/none/' | awk '/swap/' >> ${MOUNTPOINT}/etc/fstab
echo UUID=$(blkid ${DISK_PARTITION} | awk -F'UUID="' '{ print $2 }' | awk -F'"' '{ print $1 }')\ \/\ ext3\ errors\=remount\-ro\ 0\ 1 >> ${MOUNTPOINT}/etc/fstab
echo UUID=$(blkid ${DISK_BOOT_PARTITION} | awk -F'UUID="' '{ print $2 }' | awk -F'"' '{ print $1 }')\ \/\ ext3\ defaults\ 1\ 2 >> ${MOUNTPOINT}/etc/fstab
```

### network

In addition to replicating configuration files as they are, we need a more important thing: configure `udev` to translate our _NIC_ name to the old one used by _debian_. That's because from recent _Linux_ releases, the old `eth0` (or, more generally, `ethN`) has been deprecated and replaced by the `enp0sN`. Due to the fact _debian_ was basing all its configuration to the old interface name, telling `udev` to use `ethN`, we assure all the configurations we're replicating will be correctly working.

```bash
if [ -e ${MOUNTPOINT}/etc/resolv.conf ]; then
  cp -p ${MOUNTPOINT}/etc/resolv.conf{,.orig}
fi
cp -p ${MOUNTPOINT}/etc/hosts{,.orig}
cp -p ${MOUNTPOINT}/etc/hostname{,.orig}
cp -p ${MOUNTPOINT}/etc/network/interfaces{,.orig}
cp -rp ${MOUNTPOINT}/etc/network/interfaces.d{,.orig}
cp -fp /etc/resolv.conf ${MOUNTPOINT}/etc/resolv.conf
cp -fp /etc/hosts ${MOUNTPOINT}/etc/hosts
cp -fp /etc/hostname ${MOUNTPOINT}/etc/hostname
cp -rfp /etc/network/interfaces* ${MOUNTPOINT}/etc/network/
ETH_DEVICE_NAME=$(ifconfig -a | grep -i 'hwaddr' | awk '{ print $1 }')
ETH_DEVICE_HWADDR=$(ifconfig -a | tr '[:upper:]' '[:lower:]' | awk -F'hwaddr' '{ print $2 }' | grep -v ^$ | sed 's/ //g')
cat > ${MOUNTPOINT}/etc/udev/rules.d/70-persistent-net.rules << EOF
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="${ETH_DEVICE_HWADDR}", ATTR{dev_id}=="0x0", ATTR{type}=="1", NAME="${ETH_DEVICE_NAME}"
EOF
```

### users & groups

I think this is auto-explicative: we're forcing replication of any user(-or-group) with a greater(-or-equal) than 1000 id (any custom user), along with root.

```bash
(echo root; cat /etc/passwd | awk -F':' '{ if ( $3 >= 1000 ) { print $1 } }') | while read user; do
  for file in {"passwd","shadow"}; do
    line=$(grep ^${user}: /etc/${file})
    cp ${MOUNTPOINT}/etc/${file}{,.orig}
    if [[ $(grep ^${user}: ${MOUNTPOINT}/etc/${file} | wc -l) -gt 0 ]]; then
      sed -i "/^${user}:/c ${line}" ${MOUNTPOINT}/etc/${file}
    else
      echo "${line}" >> ${MOUNTPOINT}/etc/${file}
    fi
    if [[ "${file}" == "passwd" ]]; then
      home=$(echo ${line} | awk -F':' '{print $6}')
      if [[ "${home}" != "" ]]; then
        mkdir -p "${MOUNTPOINT}${home}"
        find "${home}" -maxdepth 1 | grep -v "^${home}$" | while read resource; do
          cp -rfp "${resource}" "${MOUNTPOINT}${home}/"
        done
        chown ${user}:${user} "${MOUNTPOINT}${home}" || echo "Cannot chown ${user} homedir"
      fi
    fi
  done
done
(echo root; cat /etc/group | awk -F':' '{ if ( $3 >= 1000 ) { print $1 } }') | while read group; do
  for file in {"group","gshadow"}; do
    line=$(grep ^${group}: /etc/${file})
    cp ${MOUNTPOINT}/etc/${file}{,.orig}
    if [[ $(grep ^${group}: ${MOUNTPOINT}/etc/${file} | wc -l) -gt 0 ]]; then
      sed -i "/^${group}:/c ${line}" ${MOUNTPOINT}/etc/${file}
    else
      echo "${line}" >> ${MOUNTPOINT}/etc/${file}
    fi
  done
done
```

# Final considerations

This post has been written to make some sum-ups considered useful after living my adventure summarized in the code available on [my github](https://github.com/streambinder/debubupdater), and therefore it just underlines few important steps about what the procedure actually is (or just has been in my real case). I do not expect this will solve any problem you could encounter while trying to similarly make such migrations, but at least I hope it will help you.
