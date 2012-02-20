---
layout: post
title: How to fix stdio buffering
tags: [awk, grep, sed]
---

It's a common problem.  You write some shell command like:

{% highlight console %}
$ tail -f /var/log/foo | egrep -v 'some|stuff' | sed | awk
{% endhighlight %}

and wonder why nothing is printed, even though you know some text has matched.
The problem is that stdio is being buffered, and there's a very good write-up
of the problem here so I won't repeat the technical background.

What I will provide though is how to fix it for common cases.

## stdbuf

`stdbuf` is part of GNU coreutils, and is essentially an `LD_PRELOAD` hack which
calls `setvbuf()` for an application.  Thus it is a generic solution to the
problem and can be used to fix most applications.  Usage looks like this:

{% highlight console %}
$ tail -f /var/log/foo | stdbuf -o0 app ...
{% endhighlight %}

which will disable output buffering for app, assuming it does not do something
itself to reverse the `setvbuf()` call.  An example of a misbehaving application
is `mawk`, below.

## awk

GNU `awk` needs no modifications, that is it does not buffer when there is no
controlling tty.

`mawk` however (the default `awk` in Debian/Ubuntu and possibly others) buffers
output, and also does not seem to work with `stdbuf`.  It does however provide
a `-Winteractive` option which will turn off buffering.

{% highlight console %}
$ tail -f /var/log/foo | gawk
{% endhighlight %}

or

{% highlight console %}
$ tail -f /var/log/foo | mawk -Winteractive
{% endhighlight %}

## sed

GNU `sed` provides the `-u` option which calls `fflush()`, thereby providing
unbuffered output.  You can also use `stdbuf` as above.

{% highlight console %}
$ tail -f /var/log/foo | sed -u
{% endhighlight %}

or

{% highlight console %}
$ tail -f /var/log/foo | stdbuf -o0 sed
{% endhighlight %}

## grep

Similar to `sed`, GNU `grep` provides a specific option, `--line-buffered`, to
disable buffering, or again you can use `stdbuf`.

{% highlight console %}
$ tail -f /var/log/foo | grep --line-buffered
{% endhighlight %}

or

{% highlight console %}
$ tail -f /var/log/foo | stdbuf -o0 grep
{% endhighlight %}
