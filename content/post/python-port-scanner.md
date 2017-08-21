+++

author = "d33pcode"
date = "2017-03-29T16:44:11+01:00"
description = "Implementing a port scanner in python"
draft = false
keywords = []
tags = ["programming", "python", "python2", "security", "scripts", "monitoring", "ports"]
title = "Checking ports status, the lazy way."
topics = []
type = "post"

+++

**Note:** this article will show you _some good ways_ to build a port scanner. Not _the best way_. Not the entire, fully-working, ready-for-copypasta port scanner that maybe you'll expect.

So, if you're looking for ideas and some nice snippets with their explanation, go on and read this; `else: go away`.

> Yesterday, you noticed some ports were open where they shouldn't have been.

> Nothing serious for that server, but you _have_ to know if it's an isolated case or maybe repeated for other servers before your boss (which, unfortunately, is a senior developer and was his own sysadmin before your hiring) gets to know it.

> You certainly _cannot_ manually look for open ports in every server, so you need to quickly write a script caring about performance and speed.

For the implementation, we'll use python for three main reasons:

1. the really basic syntax lets you write scripts very quickly and easily
2. the performance (for 2.7 at least) is terrific if well implemented
3. I love it. I mean, look at it. It's simply beautiful.

--------------------------------------------------------------------------------

# Basic Knocking

First of all, we need to think about how to actually check if a port is open. I tried [telnetlib](https://docs.python.org/2/library/telnetlib.html), but I personally prefer [socket](https://docs.python.org/2/library/socket.html), as I found it easier to avoid big waiting times with it. You're free to try both and let me know if you find a better way to do it.

Anyway, the socket creation will return a TCP result code (0: Success, 1:Operation not permitted, etc.) that will tell us if we can connect to it.

```python
import socket

host = "google.com"
ports = [80, 8080]

def scanPorts(host, ports):
  for port in ports:
    print("testing {0}:{1}".format(host, port))
    sock=socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result=sock.connect_ex((host, int(port)))
    sock.close()
    if result == 0:
      print('[{0}] Port {1} is open\n'.format(host, port))
```

# More hosts and config files

Easy, right? But for our problem, one host is not enough.

To make our script as generic and reusable as possible, we'll create a simple configuration file. The choice of how to actually build and manage this file is up to you, but it could be as simple as creating and parsing a small `addresslist.json`: python dict:

```json
{
    "localhost": [
        "80",
        "8080",
    ],

    "95.12.43.5": [
        "8443",
    ],

    "google.com": []
}
```

As you noticed, I also considered the case in which we need to scan all the dedicated ports: no particular port will be passed to the json object and the script will take care of scanning ports from 1 to 1024 by itself.

Parsing the JSON as a python dict is extremely simple.

```python
import json

def readConf(path):
    with open(path, 'r') as f:
        content=f.read()
    return json.loads(content) # really, THIS simple.

config=readConf('addresslist.conf')
```

Now we only need to edit the way we'll call the scanner a bit:

```python
for address in readConf('addresslist.conf'):
    if config[address]:
        scanPorts(address, config[address])
    else:
        scanPorts(address, range(1,1025))
```

# More port informations

Having the need of getting more informations about the result of the connections, I wrote a simple gist with [all the TCP return codes](https://gist.github.com/d33pcode/2542a87dd80ba35dbffd2cffbb65b53a) and parsed it as a dictionary:

```python
import requests
import ast

def getSocketCodes():
    res=requests.get(
        "https://gist.githubusercontent.com/d33pcode/2542a87dd80ba35dbffd2cffbb65b53a/raw/8a137eae6bd56ad0e55d8ea3cf1b590ef25698fe/socketcodes.txt")
    return ast.literal_eval(res.content)
```

# Multithreading

In this case, our real problem is speed.

We need to complete the scan real quick. How can we do this?

A solution could be _parallelization_. There are many ways you can implement it in this script. The first that came in my mind was to scan every host in a single thread.

Guess what? A _threading_ library is obviously provided in python, and it's as simple as this:

```python
import threading

for address in readConf('addresslist.conf'):
    if config[address]:
        t = threading.Thread(target=scanPorts, args=(address, config[address]))
        t.start()
    else:
        t = threading.Thread(target=your_function, args=(address, range(1,1025)))
        t.start()
```

Cool. Now we only have one problem: the sequential portion of code is the one that causes performance issues. If the script instantiates a thread for scanning all the default ports, it will still take really long time for it to end. To avoid this, we can divide all that ports in small batches: a thread will always call the scanner function for a small amount of ports, speeding up the execution of the default ports scanning, too.

To get the ports in batches of 20, we can do it this way:

```python
allports = range(1,1025)
sliced_ports = []
while allports:
    slice = allports[:20]
    sliced_ports.append(slice)
    allports = [p for p in allports if p not in slice]
```

At the end of the execution of that portion of code, allports will be empty and sliced_ports will contain lists of _up to_ 20 ports.

Now let's quickly edit the initial script:

```python
for address in readConf('addresslist.conf'):
    if config[address]:
        t = threading.Thread(target=scanPorts, args=(address, config[address]))
        t.start()
    else:
        allports = range(1,1025)
        sliced_ports = []
        while allports: # getting ports in batches of 20
            slice = allports[:20]
            sliced_ports.append(slice)
            allports = [p for p in allports if p not in slice]
        for ports in sliced_ports:
            t=threading.Thread(target=self.scanPorts,
                               args=(address, ports, logfile, False))
            self.threads.append(t)
            t.start()
```

## Logging things

If you want to persist the informations about the scan, you can simply open a file in read mode and use the `.flush()` method after every `.write()` to save concurrency.

```python
logfile=open('scan.log', 'w')

def scanPorts(host, ports, logfile):
  for port in ports:
    print("testing {0}:{1}".format(host, port))
    sock=socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    result=sock.connect_ex((host, int(port)))
    sock.close()
    if result == 0:
      out = '[{0}] Port {1} is open\n'.format(host, port)
      print out
      if logfile:
          logfile.write(out)
          logfile.flush()
```

And that's it. You can find my full port scanner [here](https://github.com/d33pcode/syrus-monitor/blob/master/portscanner.py).
