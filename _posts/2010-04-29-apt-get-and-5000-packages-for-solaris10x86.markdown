---
layout: post
title: "'apt-get' and 5,000 packages for Solaris10/x86"
tags: [pkgin, pkgsrc, solaris]
---

Here's how:

{% highlight console %}
# Install pkg_* tools and the 'pkgin' package manager
$ pkgadd -d http://www.netbsd.org/~sketch/TNFpkgsrc-x86.pkg all

# Add tools to PATH
$ PATH=/opt/pkg/sbin:/opt/pkg/bin:$PATH

# Update package repository (akin to 'apt-get update')
$ pkgin up

# Search for a particular package (you can use regexp)
$ pkgin search ^ap.*python 

# Install it
$ pkgin install ap22-py25-python

# Update all packages (akin to 'apt-get dist-upgrade')
$ pkgin full-upgrade

# How many packages are available?
$ pkgin avail | wc -l
   4970
{% endhighlight %}

Ok, so the headline might be slightly mis-leading, this isn't really apt-get
but a tool which is very similar. This is work which builds upon my [previous
post](/blog/2009/09/pkgsrc-on-solaris/) using pkgsrc to build binary packages
on Solaris.

See [http://imil.net/pkgin/](http://imil.net/pkgin/) for more information on
pkgin.

Hopefully this will prove really useful to people still using Solaris 10 and
unable to use the new pkg(5) stuff in OpenSolaris.

Please try it out and provide any feedback to
[pkgsrc-users@netbsd.org](mailto:pkgsrc-users@netbsd.org).  I'm hoping to keep
the packages updated for the 2009Q3 branch.
