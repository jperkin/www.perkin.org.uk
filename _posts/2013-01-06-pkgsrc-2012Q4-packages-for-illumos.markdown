---
layout: post
title: pkgsrc-2012Q4 illumos packages now available
tags: [illumos, pkgin, pkgsrc, smartos]
---

In keeping with the regular quarterly pkgsrc releases, I'm pleased to announce
that packages from the pkgsrc-2012Q4 branch are now available for general
illumos platforms.

As usual, the quick start instructions are:

{% highlight console %}
$ curl -s http://pkgsrc.smartos.org/packages/illumos/bootstrap/bootstrap-2012Q4-illumos.tar.gz \
    | gtar -zxf - -C /
$ PATH=/opt/pkg/sbin:/opt/pkg/bin:$PATH
$ pkgin -y up
$ pkgin avail | wc -l
    9518
$ pkgin search <package>
$ pkgin -y install <package> <package...>
{% endhighlight %}

For those interested in helping to increase the number of packages available,
the bulk build report for this set is available
[here](http://pkgsrc.smartos.org/reports/2012Q4-illumos/20130106.1305/meta/report.html).  It would be great to get past the 10,000 mark!
