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

**NB** I'm not following any of the _java_ frameworks, with this code. Actually it could be possible it's not working in any case.

Actually these are only the basilar properties, but what if you would keep track of the users _email_ status? What if they get closed? You might maybe want to add a field `Boolean emailStatus`, as you probably want to let users be able to only if the `email` field is valid, or you want to be sure your mail-campaigns emails get their destination.

But how to keep track of this kind of informations? You could keep track of all the emails the application is actually sending. But how? It would be really out of the application's logic to make some internal activities just to get those informations, more so if you need to introduce more and more entities (and then storing more data into your databases) just to reach your final - and primarily simple - aim, such as just knowing the email addresses status. So, let the application do what its made from, and let's think about something that can give it that informations.

# Fluent
