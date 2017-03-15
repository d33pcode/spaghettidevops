+++

type = "post"
title = "Messed up permissions. Fired."
draft = false
author = "streambinder"
date = "2017-03-15T15:28:04+01:00"
tags = ["sysadmin", "server", "linux", "redhat"]

+++

Assume you're a *systems administrator*. And you made a mistake. A terrible mistake. The kind of mistake that make you think you're a horrible and incompetent sysadmin. Ok, it's me.

I was at the head of the systems from a year and was working on a *bash* migration script for a web-server. I just needed something to move websites and SQL instances from a server to another. Oh, useless details: I was testing that script on the same machine which I would have moved everything from. The production machine.

You know, a faulty instruction in a `for` or `while` cycle and the magic begins. As probably everyone knows, mailbox folders - as everything else in a filesystem - tend to require their own specific permissions and owners in order to work properly, and that was expected by my script: it entered every mailbox folder, in every mail domain, and fixed its permissions. Assume we are on `/var/vmail/domain.net`; it contains a *boxes.txt* file, which describes many details about mail domain, its mailboxes and many other things. Now, consider this simple snippet:

```bash
cat boxes.txt | while read mailbox; do
    mailbox_user=$(echo ${mailbox} | first_manipulation)
    mailbox_full="${mailbox_user}@domain.net"
    mailbox_folder=$(echo ${mailbox} | latter_manipulation)
    cd ${mailbox_folder}
    chown -R ${mailbox_user} .
    cd ..
done
```

Ok, nothing evidently bad, if `first_manipulation` and `latter_manipulation` do their job. They currently didn't.

Actually, I wrote a `latter_manipulation` that brought my `mailbox_folder` to be non-valued, or - even worse - valued with `.`. I wasn't expected to handle a non-valued variable, though. The result? Assume that *domain.net* contained three mailboxes: *streambinder*, *d33pcode*, *bizio* and *randomguy*. My `while` cycle would do three iterations:

iteration | mailbox         | instructions
:-------: | :-------------- | :----
1         | *streambinder*  | `cd . ; chown -R streambinder . ; cd ..`
2         | *d33pcode*      | `cd . ; chown -R d33pcode . ; cd ..`
3         | *bizio*         | `cd . ; chown -R bizio . ; cd ..`
4         | *randomguy*     | `cd . ; chown -R randomguy . ; cd ..`

 So, starting from `/var/vmail/domain.net`, translated:

iteration | instructions
:-------: | :---------------------------------------------
1         | `chown -R streambinder /var/vmail/domain.net/`
2         | `chown -R d33pcode /var/vmail/`
3         | `chown -R bizio /var/`
4         | `chown -R randomguy /`

Effective result? _randomguy_ is the new systems administrator of that machine. He ownes everything on the machine. What about me? I'm fired.

Fortunately, it hasn't gone that way. But as you may understand, that was a very critical situation, in which every machine service died, as no more able to read/write any of its files, _sshd_, too.

While both shouting against myself and searching on Google for something that could save me from getting fired, found something really useful using *rpm*, *RedHat*'s package manager. Oh, if you
In fact, 90% of the filesystem could be repaired by resetting *perms* and *ugids* using packages default specifications:
```bash
for package in $(rpm -qa); do
    rpm --setperms ${package}
    rpm --setugids ${package}
done
```

Obviously it probably won't fix anything, but the most of it.
**NB**: this applies only on *RPM*-based *linux* distributions.

Finally, a really, really important hint about one of most useful utilies I found: **use scheduled getfacl**, it will save you from situations like the one above. *man* *docet*: *"for each file, getfacl displays the file name, owner, the group, and the Access Control List (ACL)"*. It's actually really useful to backup file/path permissions status, and - in case you burst again the filesystem - to restore them, this time using *setfacl* (from the same package). Schedule a daily backup of filesystem permissions status, leaning to the *crontab* utility: `crontab -e`. The *crontab* instruction `0 0 * * * getfacl -R /path/to/folderorfile > /root/backup.acl` will execute the backup daily at *00:00*.

This way you'll have a daily backup of filesystem permissions and if you have to restore the situation due to a catastrophic mistake as the one I made, just run `setfacl --restore=/root/backup.acl` and you're good to go and forgot about how stupid you are.
