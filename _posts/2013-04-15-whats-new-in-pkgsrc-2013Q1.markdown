---
layout: post
title: What's new in pkgsrc-2013Q1
tags: [illumos, osx, pkgsrc, smartos]
---

The latest branch of [pkgsrc](http://www.pkgsrc.org/) was released at the
beginning of April, and binary packages for SmartOS/illumos and OSX are now
available.

Instructions for installing, as well as a list of the major new features in
pkgsrc-2013Q1 are below.

## Installing

The instructions are similar to previous branches.

### SmartOS/illumos

SmartOS users are encouraged to use our pre-built machine images, and
installing your choice of base/standard image with version `13.1.x` (available
very soon) will get you a pkgsrc-2013Q1 based image.

For general illumos users or SmartOS users who want access to a full package
set, the instructions are below:

{% highlight console %}
$ curl http://pkgsrc.smartos.org/packages/illumos/bootstrap/bootstrap-2013Q1-illumos.tar.gz \
    | gtar -zxpf - -C /
$ PATH=/opt/pkg/sbin:/opt/pkg/bin:$PATH
$ pkgin -y update
$ pkgin avail | wc -l
    9842
$ pkgin search <package>
$ pkgin -y install <package> <package...>
{% endhighlight %}

### OSX

Beginning with pkgsrc-2013Q1 I will now be providing regular builds for OSX.
Again, the instructions are similar to those [previously
provided](/posts/7000-packages-for-osx-lion.html).

These packages are built on OSX Leopard (10.5) but use the `PREFER_PKGSRC`
mechanism to ensure that they are portable across OSX releases, and have been
successfully tested on OSX Lion (10.7).

{% highlight console %}
$ curl http://pkgsrc.smartos.org/packages/Darwin/bootstrap/bootstrap-2013Q1-Darwin.tar.gz \
    | gnutar -zxpf - -C /
$ PATH=/usr/pkg/sbin:/usr/pkg/bin:$PATH
$ pkgin -y update
$ pkgin avail | wc -l
    8108
$ pkgin search <package>
$ pkgin -y install <package> <package...>
{% endhighlight %}

## What's New

As usual there were many hundreds of changes which went into this quarterly
release of pkgsrc.  Here are some of the more interesting and useful changes.

### OpenSSL 1.0.1 with AES-NI support

OpenSSL has been upgraded from the 0.9.8 series to the 1.0.1 series.  The
driving reason to pursue this upgrade was to take advantage of AES-NI support
which significantly improves crypto performance on Intel CPUs which provide
that feature.

On my OSX 10.7 Core i7 laptop the numbers below speak for themselves:

{% highlight console %}
: /usr/bin/openssl 'OpenSSL 0.9.8r 8 Feb 2011'
$ openssl speed -evp aes-128-cbc
  type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes
  aes-128-cbc     157297.05k   173874.73k   176805.45k   177719.17k   179441.78k

: pkgsrc openssl 'OpenSSL 1.0.1e 11 Feb 2013'
$ openssl speed -evp aes-128-cbc
  type             16 bytes     64 bytes    256 bytes   1024 bytes   8192 bytes
  aes-128-cbc     643315.29k   685811.37k   696899.67k   699977.39k   693968.90k
{% endhighlight %}

A pretty significant 4x improvement for many hundreds of applications which use
OpenSSL for crypto.

### GCC Go support for SmartOS/illumos

[Go](http://golang.org/) is a reasonably new programming language from Google
that a number of our users have asked us to support, so we are pleased to
announce that beginning with pkgsrc-2013Q1 you will be able to use the `gccgo`
front-end to compile and run Go applications on SmartOS.

You simply compile the go source code as you would for any other language that
GCC supports, for example:

{% highlight console %}
$ pkgin -y install gcc47

: /opt/pkg for the illumos package set, /opt/local for SmartOS datasets..
$ PATH=/opt/pkg/gcc47/bin:$PATH

$ gccgo app.go -o app
$ ./app
{% endhighlight %}

### Networking utilities on SmartOS

Thanks to initial work by [@postwait](http://twitter.com/postwait) there is now
proper Zone support in libpcap, which has opened up the possibility to run a
number of networking utilities in Joyent SmartMachines.

Yes, this means you can finally run `tcpdump` instead of `snoop`.

One of my favourites is `trafshow` which is a top-like interface for network,
and looks like this:

<div class="postimg">
  <img src="/files/images/trafshow.png" alt="trafshow screenshot">
</div>

Alternatively you can try `nicstat` for a more `{io,mp,vm}stat` style display.

### Major package versions

As usual there was also a slew of version updates, and the most notable package
versions are listed below.  These of course are not exhaustive lists.

Development:

* Clang 3.2
* GCC 4.7.2
* Git 1.8.1.5
* Mercurial 2.5.2
* Subversion 1.6.20, 1.7.8

Languages:

* Lua 5.1.15
* Node.js 0.8.23, 0.10.2
* Ocaml 4.00.1
* Oracle JRE/JDK 6.0.37, 7.0.15
* Perl 5.16.2
* PHP 5.3.23, 5.4.13
* Python 2.6.8, 2.7.3, 3.1.5, 3.2.3, 3.3.0
* R 2.15.1
* Ruby 1.8.7.371, 1.9.3p392

Web Stack:

* Apache 1.3.42, 2.0.64, 2.2.24, 2.4.4
* CouchDB 1.2.1
* MongoDB 2.2.2
* MySQL 5.0.96, 5.1.67, 5.5.30, 5.6.10
* Nginx 1.2.7, 1.3.14
* PostgreSQL 8.3.23, 8.4.17, 9.0.13, 9.1.9, 9.2.4
* Riak 1.2.1

Desktop:

* evilwm 1.1.0
* GNOME 2.32.1, 3.6.2
* KDE 3.5.10, 4.8.4
* XFCE 4.6.1

Enjoy!
