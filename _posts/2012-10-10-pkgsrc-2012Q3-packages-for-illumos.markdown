---
layout: post
title: pkgsrc-2012Q3 packages for illumos
tags: [illumos, pkgin, pkgsrc, smartos]
---

Continuing from my [previous bulk build for
pkgsrc-2012Q2](/posts/9000-packages-for-smartos-and-illumos.html) I'm pleased
to announce that packages from the pkgsrc-2012Q3 branch are now available.

Quick start:

{% highlight console %}
$ curl -s http://pkgsrc.smartos.org/packages/illumos/bootstrap/bootstrap-2012Q3-illumos.tar.gz \
    | gtar -zxf - -C /
$ PATH=/opt/pkg/sbin:/opt/pkg/bin:$PATH
$ pkgin -y up
$ pkgin avail | wc -l
    9542
$ pkgin search <package>
$ pkgin -y install <package> <package...>
{% endhighlight %}

As usual there have been many hundreds of updates since the previous branch,
and hopefully the software you need is included.  If not, please get involved!
We welcome new contributors.

The bootstrap kit and a number of packages have been tested successfully on
OpenIndiana 151a and OmniOS.

Enjoy!
