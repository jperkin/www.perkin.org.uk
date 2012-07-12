---
layout: post
title: 7,000 binary packages for OSX Lion
tags: [osx, pkgin, pkgsrc]
---

For my [day job](http://{{ site.url }}/posts/goodbye-oracle-hello-joyent.html)
I build packages for our [SmartOS](http://smartos.org/) operating system using
pkgsrc.  pkgsrc is a cross-platform package manager which began life as the
FreeBSD ports system and was ported to NetBSD back in 1997.  Since then it has
been ported to many other different systems, 19 at the current count, one of
which is OSX/Darwin.

For the recent pkgsrc-2012Q2 release, I have performed a full bulk build on OSX
Lion, and the result is 7,374 binary packages for you to use as an alternative
to brew/macports/etc.

To use them, run the following:

{% highlight console %}
$ curl http://pkgsrc.smartos.org/packages/Darwin/2012Q2/bootstrap.tar.gz \
    | (cd /; sudo gnutar -zxpf -)
$ PATH=/usr/pkg/sbin:/usr/pkg/bin:$PATH
$ sudo pkgin -y update
$ pkgin avail | wc -l
    7374
$ pkgin search ...
$ sudo pkgin -y install ...
{% endhighlight %}

`pkgin` is a tool similar to `apt-get` and allows you to easily search for and
install/upgrade packages.

Please let me know if you find them useful, and if you have any feedback.

Enjoy!
