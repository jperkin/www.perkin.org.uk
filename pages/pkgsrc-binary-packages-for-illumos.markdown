---
layout: static
title: pkgsrc binary packages for illumos
---

[pkgsrc](http://www.pkgsrc.org/) is a cross-platform packaging framework,
designed to build a large number of third-party open source software
packages on many different operating systems.  It is the primary package
manager on [Joyent](http://www.joyent.com/)'s [SmartOS](http://smartos.org/)
distribution, and the packages are built portably so that they can be used
unmodified on other illumos distributions as well.

Included in the binary package set is the `pkgin` package manager which is
designed to look and function very similar to `apt-get`, making it very easy
to add, upgrade, and remove packages.

Currently there are over 11,000 up-to-date binary packages available, built
for individual 32-bit and 64-bit sets, as well as a combined multiarch set.

pkgsrc is released every quarter, and the current release is 2013Q3.

## Quick Start

{% highlight console %}
: Install either the 32-bit bootstrap..
$ curl -s http://pkgsrc.joyent.com/packages/SmartOS/bootstrap/bootstrap-2013Q3-i386.tar.gz \
    | gzcat | (cd /; sudo tar -xpf -)

: ..or the 64-bit bootstrap..
$ curl -s http://pkgsrc.joyent.com/packages/SmartOS/bootstrap/bootstrap-2013Q3-x86_64.tar.gz \
    | gzcat | (cd /; sudo tar -xpf -)

: ..or the multiarch bootstrap.
$ curl -s http://pkgsrc.joyent.com/packages/SmartOS/bootstrap/bootstrap-2013Q3-multiarch.tar.gz \
    | gzcat | (cd /; sudo tar -xpf -)

: Packages are kept under /opt/local, add to $PATH
$ PATH=/opt/local/sbin:/opt/local/bin:$PATH

: Refresh the package repository to get the very latest packages
$ sudo pkgin -y update

: Find out what packages (and how many) are available
$ pkgin avail | wc -l

: Search for a particular package, for example 'tmux'
$ pkgin search tmux

: Install a package
$ sudo pkgin -y install tmux

: Upgrade all packages
$ sudo pkgin -y full-upgrade
{% endhighlight %}

## Building From Source

pkgsrc is based on the FreeBSD [ports](http://www.freebsd.org/ports/) system,
so if you are used to that (or other similar forks such as OpenBSD ports) and
want to build packages from source the procedure is very similar:

{% highlight console %}
: Install the git package and fetch pkgsrc from the converted cvs->git repo
$ sudo pkgin -y install git
$ git clone git://github.com/joyent/pkgsrc.git

: By default you will get pkgsrc trunk.  If you want the most recent stable
: branch, then switch to it first.
$ git checkout joyent/release/2013Q2              # for 32-bit/64-bit
$ git checkout joyent/release/2013Q2_multiarch    # for multiarch

: Change to the package directory and download/compile/install with one command.
$ cd pkgsrc/<category>/<package>
$ bmake install
{% endhighlight %}

Here are some common configuration settings you may wish to add to
`/opt/local/etc/mk.conf`:

{% highlight make %}
# Avoid root password prompt for package install/deinstall
SU_CMD=		sudo /bin/sh -c

# Re-use existing binary packages, replace <ARCH> with the bootstrap you
# chose earlier, i.e. 'i386', 'x86_64', or 'multiarch'.
BINPKG_SITES=	http://pkgsrc.joyent.com/packages/SmartOS/2013Q2/<ARCH>
DEPENDS_TARGET=	bin-install

# Build everything with -j8
MAKE_JOBS=	8

# Ignore vulnerability and license checks
ALLOW_VULNERABLE_PACKAGES=	yes
SKIP_LICENSE_CHECK=		yes

# Configure where to store distfiles, binary packages, and build areas
DISTDIR=	/content/distfiles
PACKAGES=	/content/packages
WRKOBJDIR=	/var/tmp/pkgsrc-build
{% endhighlight %}

If you want to change the build options for a particular package, first find
out which options are available with `show-options`, and then set the
particular option in `/opt/local/etc/mk.conf` before building:

{% highlight console %}
$ cd pkgsrc/net/nmap

$ bmake show-options
Any of the following general options may be selected:
	inet6	 Enable support for IPv6.
	ndiff	 Enable tool to compare Nmap scans.
	zenmap	 Enable nmap GUI frontend.

These options are enabled by default:
	inet6

These options are currently enabled:
	inet6

You can select which build options to use by setting PKG_DEFAULT_OPTIONS
or PKG_OPTIONS.nmap.

$ vi /opt/local/etc/mk.conf
PKG_OPTIONS.nmap+=	ndiff

$ bmake install
{% endhighlight %}

## Further Information

The [pkgsrc guide](http://www.netbsd.org/docs/pkgsrc/) is packed with
information about the internals of pkgsrc, and is useful if you would like to
dig deeper and start hacking.

There are also various [pkgsrc-related posts](/tags/pkgsrc.html) on my blog
which contain various hints and tricks.  I also post new branch
builds and updates there.

We hang out on Freenode `#pkgsrc`, and our mailing lists are:

* [pkgsrc-users@netbsd.org](mailto:pkgsrc-users@netbsd.org) for users
* [tech-pkg@netbsd.org](mailto:tech-pkg@netbsd.org) for developers

## Get Involved

There are over 13,000 packages in pkgsrc, so there are quite a few which
currently do not build on illumos.  We perform regular bulk builds that are
posted to the [pkgsrc-bulk@netbsd.org](mailto:pkgsrc-bulk@netbsd.org) mailing
list, which shows all the currently failing packages as well as their build
logs [here](http://mail-index.netbsd.org/pkgsrc-bulk/):

Build fixes, package updates as well as new packages are very welcome:

* If you have a small patch and prefer using GitHub, feel free to raise it as
  an [issue](https://github.com/joyent/pkgsrc/issues) against Joyent's
  [pkgsrc](https://github.com/joyent/pkgsrc) repository.

* If you want to get involved in creating new packages, the
  [pkgsrc-wip](http://pkgsrc-wip.sourceforge.net/) project is a great way to
  get started.

* Otherwise, there is always the [NetBSD GNATS
  database](http://www.netbsd.org/support/send-pr.html).

## Finally

Enjoy!
