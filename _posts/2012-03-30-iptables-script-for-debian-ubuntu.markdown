---
layout: post
title: iptables script for Debian / Ubuntu
tags: [debian, ubuntu, iptables]
---

Most Linux distributions seem to have their own way of handling iptables.  Red
Hat based distributions come with an init script `/etc/init.d/iptables` which
saves/restores configuration and allows you to check the status.

Debian / Ubuntu come with .. nothing.

So, there is a plethora of advice and ways of setting iptables up them, and
this is mine.

It's a simple shell script which is installed to
`/etc/network/if-pre-up.d/iptables`, meaning it is executed prior to an
interface being brought up - better to do it then than afterwards :)

I provide a couple of shell functions to make it easy write rules which are to
be applied to both IPv4 and IPv6.

Here it is in its entirety, feel free to use/copy/whatever, it's public domain.

{% highlight bash %}
{% include iptables-example %}
{% endhighlight %}

Just remember to make it executable ;-)
