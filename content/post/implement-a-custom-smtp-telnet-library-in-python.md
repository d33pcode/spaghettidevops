+++

type = "post"
title = "Implement a custom SMTP-Telnet library in python"
draft = false
author = "streambinder"
date = "2017-03-17T12:24:00+01:00"
tags = ["programming", "python", "python2", "telnet", "socket", "smtp"]

+++


Why the fuck you should implement a custom _telnet_ library in _python_? Don't you know how _telnet_ protocol is obsolete, unsecure and - above all - already implemented by [telnetlib](https://docs.python.org/2/library/telnetlib.html)?

Yup, I obviously know it. But two reasons guided me into the - simple, indeed - adventure of rewriting the standard _telnetlib_ using [socket](https://docs.python.org/2/library/socket.html)? library:

1. I needed it, as _telnetlib_ didn't support passing source IP to the socket creation. This caused the application to use always the same IP (the default one), even if the machine I was running it on owned several IPs.
2. I wanted to do it, just to try to understand how things work down there.

That said, let's introduce the problem: **why did I need to implement this library?**. Well, do you know what emails are? I think so. Then, starting from a list of email addresses, I needed to know if they were alive. And the easiest and rudimental approach would be firing thousands emails from a _Postfix_ server, for example, and reading back its log to know where those fires are gone. Actually it was working like that, in the beginning.

But what about studying a little bit more the _SMTP_ protocol? Does anybody know how does it works, or at least, starts? Trust me: in an _SMTP_ conversation, you always start by introduce yourself; once the other side answers that it's ok with talking with you, you specify a mail address, the one you want to send data with; once - or if - the other side is ok again, you can specify the recipient address, and the other side will answer to you basicly with _"ok, tell me what to tell him"_ or _"no, who the fuck is him?"_. Actually it's not right that way, but you only need to know that in the last step we can obtain the information we're looking for. So, every _SMTP_ conversation starts with these three steps; let's have a more detailed look at them:

phase number | phase appellation | example request                         | example answer
:----------: | :---------------: | :-------------------------------------- | :----------------------------------------------------------------------------------------------
     1       |     **HELO**      | `helo src.mail.company.net`             | `250 dst.mail.company.net`
     2       |   **MAIL FROM**   | `mail from: <streambinder@company.net>` | `250 2.1.0 Ok`
     3       |    **RCPT TO**    | `rcpt to: <d33pcode@company.net`        | `250 2.1.5 Ok` or `550 5.1.1 Recipient address rejected: User unknown in virtual mailbox table`

This is more or less what happens when you handle this conversation using _telnet_ (example of _telnet_ via shell):

```bash
[streambinder@workstation.company.net ~]$ telnet dst.mail.company.net 25
Trying 192.168.0.254...
Connected to dst.mail.company.net.
Escape character is '^]'.
220 dst.mail.company.net ESMTP Postfix
> helo src.mail.company.net
250 dst.mail.company.net
> mail from: <streambinder@company.net>
250 2.1.0 Ok
> rcpt to: <d33pcode@company.net>
250 2.1.5 Ok
```

So I needed a way to handle this conversation using _python_, inside a bigger and more complex ecosystem. Actually decided to implement something that could be handled easier than using _socket_ provided APIs. So, my needs brought me to write the code below.

```python
import errno
import socket
import time

class TelnetTimeoutException(Exception):
    def __init__(self, host, timeout):
        super(TelnetTimeoutException, self).__init__("No response in " + str(timeout) + " seconds from " + str(host) + ".")

class TelnetClosedException(Exception):
    def __init__(self, host):
        super(TelnetClosedException, self).__init__("Socket already closed by " + str(host) + ".")

class TelnetNoRouteException(Exception):
    def __init__(self, host):
        super(TelnetNoRouteException, self).__init__("No route to host " + str(host) + ".")

class TelnetBlacklistedException(Exception):
    def __init__(self, host, code, message):
        super(TelnetBlacklistedException, self).__init__(str(host) + " blacklisted you: \"[" + str(code) + "]" + str(message) + "\".")

class TelnetGreylistedException(Exception):
    def __init__(self, host, code, message):
        super(TelnetGreylistedException, self).__init__(str(host) + " greylisted you: \"[" + str(code) + "]" + str(message) + "\".")

class TelnetTooMuchRcptsException(Exception):
    def __init__(self, host):
        super(TelnetTooMuchRcptsException, self).__init__("Too much RCPT messages to " + str(host) + " (" + str(Telnet.SOCK_MAX_RCPTS) + ").")

class TelnetReply():
    def __init__(self, reply=None):
        if reply is not None:
            reply = reply.replace('\n', '').replace('\r', '')
        self.code = self.parseCode(reply)
        self.host = self.parseHost(reply)
        self.msg = self.parseMsg(reply)
    def parseCode(self, reply):
        try:
            if reply[0:3].isdigit():
                return str(reply[0:3])
        except:
            pass
        return "000"
    def parseHost(self, reply):
        try:
            return str(reply.split()[1])
        except:
            pass
        return "unknown"
    def parseMsg(self, reply):
        try:
            return str(" ".join(reply.split()[2:]))
        except:
            pass
        return ""
    def isEmpty(self):
        return self.code == "000" and self.msg == ""

class Telnet():
    SOCK_MAX_RCPTS = 100
    SOCK_READ_INTERVAL = 5 # second(s)
    SOCK_TIMEOUT = 30 # second(s)
    PHASE_NEWBORN = 0
    PHASE_HELO = 1
    PHASE_MAILFROM = 2
    PHASE_RCPT = 3
    def __init__(self, to_h, to_p, from_h, from_p=0, timeout=Telnet.SOCK_TIMEOUT):
        self.to = tuple([to_h, to_p])
        self.me = tuple([from_h, from_p])
        self.timeout = timeout
        self.sock = None
        self.phase = Telnet.PHASE_NEWBORN
        self.rcpts = 0
        self.connect()
    def to_host(self):
        return self.to[0]
    def to_port(self):
        return self.to[1]
    def me_host(self):
        return self.me[0]
    def me_port(self):
        return self.me[1]
    def connect(self):
        if self.sock is None:
            print "DEBUG: Instanciating socket between " + str(self.me_host()) + ":" + str(self.me_port()) + " and " + str(self.to_host()) + ":" + str(self.to_port())
            try:
                self.sock = socket.create_connection(self.to, self.timeout, self.me)
                print "DEBUG: Instanciated. Gonna listen for some welcome."
                self.listen()
            except socket.timeout:
                print "DEBUG: Instanciating socket timeout."
                raise TelnetTimeoutException(self.to_host(), self.timeout)
            except socket.error as e:
                if e.errno is errno.EHOSTUNREACH:
                    raise TelnetNoRouteException(self.to_host())
    def integrity_check(self):
        if self.sock is None:
            self.connect()
    def listen(self):
        return self.tell()
    def tell(self, msg=None):
        self.integrity_check()

        if msg != None:
            if msg.lower()[:4] == "helo":
                self.phase = Telnet.PHASE_HELO
            elif msg.lower()[:9] == "mail from":
                self.phase = Telnet.PHASE_MAILFROM
            elif msg.lower()[:7] == "rcpt to":
                self.phase = Telnet.PHASE_RCPT
                self.rcpts += 1
                if Telnet.SOCK_MAX_RCPTS > 0 and self.rcpts == Telnet.SOCK_MAX_RCPTS:
                    raise TelnetTooMuchRcptsException(self.to_host())
            print "DEBUG: Tell: \"" + msg + "\""
            try:
                self.sock.send((msg if msg is not None else "") + '\r\n')
            except socket.error as e:
                if e.errno is errno.EHOSTUNREACH:
                    raise TelnetNoRouteException(self.to_host())
                elif e.errno in [errno.EHOSTUNREACH, errno.ECONNRESET]:
                    raise TelnetClosedException(self.to_host())
                elif e.errno is errno.EPIPE:
                    pass
                else:
                    raise
            except AttributeError as e:
                raise TelnetClosedException(self.to_host())

        reply = TelnetReply()
        try:
            reply = TelnetReply(self.sock.recv(4096))
            attempts = 0
            while reply.isEmpty() and int(attempts / (1 / Telnet.SOCK_READ_INTERVAL)) >= self.timeout:
                reply = TelnetReply(self.sock.recv(4096))
                attempts += 1
                time.sleep(0.5)
            if reply.isEmpty():
                raise TelnetTimeoutException(self.to_host(), self.timeout)
            print "DEBUG: Recv: \"[" + reply.code + "]" + (" " + reply.msg if len(reply.msg) > 0 else str()) + "\""
            if not reply.code[0] == "2" and ("greylist" in reply.msg.lower() or "too busy" in reply.msg.lower() or "try later" in reply.msg.lower() or "try again in" in reply.msg.lower()):
                raise TelnetGreylistedException(self.to_host(), reply.code, reply.msg)
            elif not reply.code[0] == "2" and ("blacklist" in reply.msg.lower() or ("blocked" in reply.msg.lower() and "ip" in reply.msg.lower())) and not "not exist" in reply.msg.lower():
                raise TelnetBlacklistedException(self.to_host(), reply.code, reply.msg)
        except socket.timeout:
            print "DEBUG: Got not reply."
            raise TelnetTimeoutException(self.to_host(), self.timeout)
        except socket.error as e:
            if e.errno is errno.ECONNRESET:
                raise TelnetClosedException(self.to_host())
        return reply
    def quit(self):
        if self.sock is not None:
            self.sock.close()
        self.sock = None
```

I know, I can't mash this code right here without any explaination. So, let's check every part:

1. `Telnet` object: this is actually the core part of the implementation. As you could read in the `__init__` function, it takes several parameters:

  - `to_h` (for _to host_): the destination host IP (or hostname);
  - `to_p` (for _to port_): the destination host _SMTP_ port (you know, it could be listening on several ports, although it's supposed to work on 25);
  - `from_h` (for _from host_): the source host IP, to decide on which local IP instanciate the connection;
  - `from_p` (for _from port_): the source host port, if needed. Actually it's set to 0 by default, so to delegate the decision to the operating system;
  - `timeout`: the instanciating and operating service timeout. The object set the phase of the conversation to `PHASE_NEWBORN`, resets the read RPCTs counter and tries to open the connection. Once ready, you can interact with the connection using the `tell()` function. If no argument is passed to it, it will somehow ping to the destination host (in the instanciating process, it's needed to wait the destination host to give us the welcome message), otherwise it's supposed to be used passing the _SMTP_ specific messages, such as the ones already explained (_helo_, _mail from_ and _rcpt to_). Everytime the object catch an output message, it will parse it into an helper object, the `TelnetReply`.

2. `TelnetReply`: as mentioned, it's an helper object that parse rude connection messages into a more manageable and readable structure. Once ready, you could access output message using field `telnet_reply.msg` and output code using field `telnet_reply.code`. It actually can also provide host which the message came from, but it's not that needed, as already known from `Telnet` instance.

3. Exceptions: there're several exceptions.

  - `TelnetTimeoutException`: everytime any `Telnet` instance operation takes longer than expected by the field `timeout`, a `TelnetTimeoutException` is raised;
  - `TelnetClosedException`: raised if a _telnet_ operations fails due to socket closure by the destination host;
  - `TelnetNoRouteException`: if the `Telnet` instance is not able to reach the destination host, it gets raised;
  - `TelnetBlacklistedException`: raised if the `Telnet` instance detects a blacklist on the source IP while doing any kind of operation;
  - `TelnetGreylistedException`: raised if the `Telnet` instance detects a greylist on the source IP while doing any kind of operation;
  - `TelnetTooMuchRcptsException`: raised if the `Telnet` instance has asked more than its `SOCK_MAX_RCPTS` constant RCPTs.

Finally, this is actually what happens - in the same case of the shell example provided above - using this implementation:

```python
import sys
import telnet
import time

try:
    sock = telnet.Telnet("dst.mail.company.net", 25, "192.168.0.253")
    reply = sock.tell("helo src.mail.company.net")
    if reply.code[0] is not "2":
        print "ERROR: not expected \"helo\" output code."
    reply = sock.tell("mail from: <streambinder@company.net>")
        if reply.code[0] is not "2":
            print "ERROR: not expected \"mail from\" output code."
    reply = sock.tell("rcpt to: <d33pcode@company.net>")
        if reply.code[0] is not "2":
            print "ERROR: not expected \"rcpt to\" output code."
        else:
            print "d33pcode@company.net seems to be alive."
except (telnet.TelnetTimeoutException, telnet.TelnetNoRouteException) as e:
    print "ERROR: " + str(e)
    try:
        sock.quit()
    except:
        pass
except telnet.TelnetBlacklistedException as e:
    print "ERROR: " + str(e)
    sys.exit(0)
except telnet.TelnetGreylistedException as e:
    print "ERROR: " + str(e)
    time.sleep(120)
```

So, it's actually a very basilar _telnet_ implementation, written exclusively to fit my context needs. I would be really glad to hear this helped someone. Obviously, if you need, feel free to extend it.
