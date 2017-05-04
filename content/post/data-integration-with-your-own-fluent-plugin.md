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

The approach I often used is to intepret processes logs to get those relevant informations. In this specific case, the solution would be, for example, track all the _Postfix_ logs (I assume you're actually using _Postfix_. If not, please, replace all `Postfix` occurrences with your preferred mail server software).
Think of this `tail` shell command: `tail -f /var/log/maillog`. You'll live receive any log change on stdout. So you'll maybe want to filter lines and store informations into variables to manipulate them and eventually push in any way into the database:
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

## Fluent regex tester
fluentular.herokuapp.com

#rsyslog to share logs
