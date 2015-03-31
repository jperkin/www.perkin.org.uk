---
layout: post
title: What's new in pkgsrc-2013Q2
tags: [illumos, osx, pkgsrc, smartos]
---

## Note

__This page is obsolete.__  Please see <http://pkgsrc.joyent.com/> where you
will find the latest package sets and improved instructions.

## Original Article

The latest branch of [pkgsrc](http://www.pkgsrc.org/) was released at the
beginning of July, and binary packages for SmartOS/illumos and OSX are now
available.

On OSX there are almost 9,000 binary packages available, whilst on illumos we
finally breached the 10,000 package mark!  Congratulations to everyone who has
worked on SunOS pkgsrc support over the past 15 years, this is a great
milestone.

## Installing

Please see the individual instruction pages for your platform:

* [OSX](/pages/pkgsrc-binary-packages-for-osx.html)
* [illumos](/pages/pkgsrc-binary-packages-for-illumos.html)

## What's New

As usual there were many hundreds of changes which went into this quarterly
release of pkgsrc.  Here are some of the more interesting and useful changes.

### OpenJDK7 is now default

Thanks to the great work by SmartOS user 'jesse', we now have a working
OpenJDK7 on illumos, built with GCC.  This is now the default JRE/JDK, as we
are unable to provide updated sun-{jre,jdk} packages due to Oracle's more
restrictive redistribution policies.

The only user-visible change from this is that the Java binaries are prefixed
with `openjdk7-`, so call e.g. `openjdk7-java` instead of `java`, or
alternatively put `/opt/local/java/openjdk7/bin` at the front of your `$PATH`.

This allows co-existance with the legacy sun-{jre,jdk} packages.

### Desktop support

Thanks to many Xorg updates from Richard Palo, Xorg is now functional on
illumos, enabling many common desktop environments to now be used.

{% highlight console %}
: Install the meta-package containing Xorg
$ pkgin in modular-xorg

: On OmniOS these are required on top of the basic install.
$ pkg install driver/x11/xsvc developer/macro/cpp

: Also on OmniOS 'od' is located in a different location
$ sed -i -e 's,/usr/bin/od,/usr/gnu/bin/od,' /opt/local/bin/startx
{% endhighlight %}

Here are some examples and how to install them:

#### GNOME 2.32 with Evolution and Firefox 22.

Screenshot:

<div class="postimg">
  <a href="/files/images/2013Q2-gnome.png">
    <img src="/files/images/2013Q2-gnome.png" alt="GNOME 2.32">
  </a>
</div>

Install:

{% highlight console %}
$ pkgin in gnome-session gnome-themes gnome-themes-extras \
           gnome-terminal gnome-backgrounds evolution

$ vi .xinitrc
#!/bin/sh
PATH=/opt/local/sbin:/opt/local/bin:$PATH
/opt/local/bin/gnome-session

$ startx

: Currently the pkgsrc firefox22 fails on startup, so for now use the
: pre-built binaries from Mozilla (with some library hacks).
$ curl -s http://releases.mozilla.org/pub/mozilla.org/firefox/releases/latest/contrib/solaris_tarball/firefox-22.0.en-US.opensolaris-i386.tar.bz2 \
    | bzcat | tar -xf -
$ ln -s /opt/local/lib/libX11.so firefox/libX11.so.4
$ ln -s /opt/local/lib/libXt.so firefox/libXt.so.4
$ env LD_LIBRARY_PATH=/opt/local/lib ./firefox/firefox
{% endhighlight %}

#### KDE 4.10.3

Screenshot:

<div class="postimg">
  <a href="/files/images/2013Q2-kde4.png">
    <img src="/files/images/2013Q2-kde4.png" alt="KDE 4.10.3">
  </a>
</div>

Install:

{% highlight console %}
$ pkgin in kde-runtime4 kde-workspace4 kde-baseapps4 \
           kde-wallpapers4 kde-base-artwork konsole

$ vi .xinitrc
/opt/local/bin/startkde
{% endhighlight %}

#### XFCE 4.6 with Gnumeric and Abiword

Screenshot:

<div class="postimg">
  <a href="/files/images/2013Q2-xfce4.png">
    <img src="/files/images/2013Q2-xfce4.png" alt="XFCE 4.6">
  </a>
</div>

Install:

{% highlight console %}
$ pkgin in xfce4 gnumeric abiword

$ vi .xinitrc
/opt/local/bin/xfce4-session
{% endhighlight %}

#### Enlightenment 0.17 with GIMP

Screenshot:

<div class="postimg">
  <a href="/files/images/2013Q2-e17.png">
    <img src="/files/images/2013Q2-e17.png" alt="Enlightenment 0.17">
  </a>
</div>

Install:

{% highlight console %}
$ pkgin in enlightenment-0.17 gimp

$ vi .xinitrc
/opt/local/bin/enlightenment_start
{% endhighlight %}

#### Awesome 3.4.13

And finally, for you terminal fans ;)

<div class="postimg">
  <a href="/files/images/2013Q2-awesome.png">
    <img src="/files/images/2013Q2-awesome.png" alt="Awesome 3.4.13">
  </a>
</div>

Install:

{% highlight console %}
$ pkgin in awesome

$ vi .xinitrc
/opt/local/bin/awesome
{% endhighlight %}

## Finally

Enjoy!
