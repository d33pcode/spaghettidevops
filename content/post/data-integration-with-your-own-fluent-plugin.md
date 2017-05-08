+++

author = "streambinder"
date = "2017-04-29T13:58:36+02:00"
description = "Write your own Fluent plugin to integrate data from logs flows"
draft = true
keywords = []
tags = ["sysadmin", "fluent", "server", "logging", "ruby"]
title = "Data integration with your own Fluent plugin"
topics = []
type = "post"

+++

Have you ever had the needing to integrate informations from not-directly-handled sources into your application?

Assume you're developing a social network. Assume you're following the [MVC](https://it.wikipedia.org/wiki/Model-View-Controller) architectural pattern logic. You will probably have an _entity_ that will define every standard user behaviors and specifications. Among all the properties a user could be defined from, which is the field that bestly describe it? Better: which is that field that usually uniquely describe it? Actually the email one, even if recently also the phone number is taking up its space.

A standard user entity could be described by the following code:

```java
public class User extends Entity {

    private Integer id;
    private String nickname;
    private String firstName;
    private String lastName;
    private String email;
    private String passwordHash;

}
```

**NB** This code is actually just a snippet written to give you the idea of the logic, `Entity` class is completely invented.

Actually these are only the basilar properties, but what if you would keep track of the users _email_ status? What if they get closed? You might want to add a field `Boolean emailStatus`, as you probably want to let users be able to login only if the `email` field is valid, or you want to be sure your mail-campaigns emails get their destinations.

But how to keep track of this kind of informations? You should track all the emails the application is actually sending. But how? It would be really out of the application's logic to make some internal activities just to get those informations, more so if you need to introduce more and more entities (and then storing more data into your databases) just to reach your final - and primarily simple - aim, such as just knowing the email addresses status. So, let the application do what its made from, and let's think about something that can give it that informations.

# Rural is for men

The approach I often used is to intepret processes logs to get those relevant informations. In this specific case, the solution would be, for example, track all the _Postfix_ logs (I assume you're actually using _Postfix_. If not, please, replace all `Postfix` occurrences with your preferred mail server software). Think of this `tail` shell command: `tail -f /var/log/maillog`. You'll live receive any log change on stdout. So you'll maybe want to filter lines and store informations into variables to manipulate them and eventually push in any way into the database:

```bash
tail -n1 -f /var/log/maillog | awk '/status=/' | while read line; do
    email_stat=$(echo ${line} | awk -F'status=' '{ print $2 }' | awk '{ print $1 }')
    email_addr=$(echo ${line} | awk -F'to=<' '{ print $2 }' | awk '{ print $1 }')
    mysql -u root database "insert into Email (`address`,`status`) values ('${email_addr}','${email_stat}');"
done
```

It works. It's simple. It's not that efficient. It's not rockly stable. And I'm not talking about this specific snippets, but about this logic, instead. You could choose this one, if your data flow is not that big, but if you always send thousands emails per hour, you should look somewhere else, for something more deeply thought.

The solution I recently got in touch with is _fluent_.

# Fluentd

> Fluentd is an open source data collector, which lets you unify the data collection and consumption for a better use and understanding of data.

> It tries to structure data as JSON as much as possible: this allows Fluentd to unify all facets of processing log data: collecting, filtering, buffering, and outputting logs across multiple sources and destinations (Unified Logging Layer). The downstream data processing is much easier with JSON, since it has enough structure to be accessible while retaining flexible schemas.

> It has a flexible plugin system that allows the community to extend its functionality. Our 500+ community-contributed plugins connect dozens of data sources and data outputs. By leveraging the plugins, you can start making better use of your logs right away.

> It is written in a combination of C language and Ruby, and requires very little system resource. The vanilla instance runs on 30-40MB of memory and can process 13,000 events/second/core.

> It supports memory- and file-based buffering to prevent inter-node data loss. Fluentd also support robust failover and can be set up for high availability. 2,000+ data-driven companies rely on Fluentd to differentiate their products and services through a better use and understanding of their log data.

Advertising apart, _Fluent_ is a really useful software born to efficiently handle several log flows and do some activities upon the data its receiving from them.

Back to the originary problem, once installed, we can configure it to pull some lines from _Postfix_ log. We basically impose a _regex_ string that has to match the log line type to pull and push it to a plugin that handle and insert data into the application. This way, the application itself won't need to do anything but wait to obtain informations about email addresses status.

## Log source

As just mentioned, we need to create a _regex_ string, needed to find the type of log line we want to interpret. So, as in the example of the _"rural script example"_, we want to handle a standard _Postfix_ status line, such as the following:

```
Mar 27 12:34:45 server postfix/smtp[12345]: D09C7A0281: to=<some@o.ne>, relay=localhost[127.0.0.1]:25, delay=0.29, delays=0/0/0.1/0.19, dsn=2.0.0, status=sent (250 2.0.0 Ok: queued as 337CF5FD07)
```

Actually the only informations we need are the `to=<some@o.ne>` and the `status=sent` fields, but we need to make the whole line parseable. This example _regex_ should do the trick:

```
/^(?<prefix_weekday>[^ ]*) (?<prefix_day>[^ ]*) (?<prefix_hour_h>[^:]*):(?<prefix_hour_m>[^:]*):(?<prefix_hour_s>[^:]*) (?<prefix_hostname>[^ ]*) (?<prefix_instance>[^ ]*): (?<queueid>[^ ]*): to=<(?<rcpt_to>[^ ]*)>, relay=(?<relay>[^ ]*), [^*]* status=(?<status>[^ ]*) (?<message>[^/]*)/
```

And, applied on the example log line above, will lead you to be able to handle a json with the following parameters:

```json
{
    "prefix_weekday": "Mar",
    "prefix_day": 27,
    "prefix_hour_h": 12,
    "prefix_hour_m": 34,
    "prefix_hour_s": 45,
    "prefix_hostname": "server",
    "prefix_instance": "postfix/smtp[12345]",
    "queueid": "D09C7A0281",
    "rcpt_to": "some@o.ne",
    "relay": "localhost[127.0.0.1]:25",
    "status": "sent",
    "message": "250 2.0.0 Ok: queued as 337CF5FD0"
}
```

Once we defined a working _regex_, we need to tell _fluent_ how and on which file apply that filter. This will be our input module:

```
<source>
    @type tail
    path /var/log/maillog
    tag system
    format /^(?<prefix_weekday>[^ ]*) (?<prefix_day>[^ ]*) (?<prefix_hour_h>[^:]*):(?<prefix_hour_m>[^:]*):(?<prefix_hour_s>[^:]*) (?<prefix_hostname>[^ ]*) (?<prefix_instance>[^ ]*): (?<queueid>[^ ]*): to=<(?<rcpt_to>[^ ]*)>, relay=(?<relay>[^ ]*), [^*]* status=(?<status>[^ ]*) (?<message>[^/]*)/
</source>
```

### What if I'm not the mail server?

In this case, you'll need a little hack. First of all, move to the mail server, and add this line to fire all its mail logs to our _rsyslog_ machine, too:
```
mail.* @192.168.0.1:5140
```
**NB** `192.168.0.1` is the _rsyslog_ machine itself.

Finally, let's modify the _Fluent_ configuration to make it be listening on the network for incoming logs with `system` tag:
```
<source>
  @type syslog
  port 5140
  bind 0.0.0.0
  tag system
  format /^(?<prefix_weekday>[^ ]*) (?<prefix_day>[^ ]*) (?<prefix_hour_h>[^:]*):(?<prefix_hour_m>[^:]*):(?<prefix_hour_s>[^:]*) (?<prefix_hostname>[^ ]*) (?<prefix_instance>[^ ]*): (?<queueid>[^ ]*): to=<(?<rcpt_to>[^ ]*)>, relay=(?<relay>[^ ]*), [^*]* status=(?<status>[^ ]*) (?<message>[^/]*)/
</source>
```
