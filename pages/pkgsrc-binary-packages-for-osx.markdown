---
layout: static
title: pkgsrc binary packages for Mac OSX
---

## Note

__This page is obsolete.__  Please see <http://pkgsrc.joyent.com/> where you
will find the latest package sets and improved instructions.

## Original Article

[pkgsrc](http://www.pkgsrc.org/) is a cross-platform packaging framework,
designed to build a large number of third-party open source software packages
on many different operating systems.

[Joyent](http://www.joyent.com/) provide a regular bulk build of all packages
on OSX, which you can easily download and install onto your systems.  Included
is the `pkgin` package manager which is designed to look and function very
similar to `apt-get`.

Currently there are over 11,000 up-to-date binary packages available.  The
packages are built on OSX Snow Leopard (10.6) and linked against libraries from
pkgsrc, so that they are generic enough to run on all modern versions of OSX.

The current release is `pkgsrc-2014Q2`.

## Quick Start

If you have already installed a pkgsrc bootstrap, you should be able to upgrade
to the latest release simply by updating the `pkgin` URL and upgrading all
packages:

{% highlight console %}
: Assuming an upgrade from 2014Q1..
$ sudo ed /usr/pkg/etc/pkgin/repositories.conf <<EOF
%s/2014Q1/2014Q2/g
wq
EOF
$ sudo pkgin -y update
$ sudo pkgin -y full-upgrade
{% endhighlight %}

Otherwise install a new bootstrap:

{% highlight console %}
: Download and install the bootstrap containing pkgin and the packaging tools
$ curl http://pkgsrc.joyent.com/packages/Darwin/bootstrap/bootstrap-2014Q2-i386.tar.gz | sudo tar -zxpf - -C /

: Packages are kept under /usr/pkg, add to $PATH
$ PATH=/usr/pkg/sbin:/usr/pkg/bin:$PATH

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
want to build from source the procedure is very similar:

{% highlight console %}
: Install the git package and fetch pkgsrc from the converted cvs->git repo
$ sudo pkgin -y install scmgit
$ git clone git://github.com/jsonn/pkgsrc.git

: By default you will get pkgsrc trunk.  If you want the most recent stable
: branch, then switch to it first.
$ git checkout pkgsrc_2014Q2

: Change to the package directory and download/compile/install with one command.
$ cd pkgsrc/<category>/<package>
$ bmake install
{% endhighlight %}

Here are some common configuration settings you may wish to add to
`/usr/pkg/etc/mk.conf`:

{% highlight make %}
# Avoid root password prompt for package install/deinstall
SU_CMD=		sudo /bin/sh -c

# Re-use existing binary packages
BINPKG_SITES=	http://pkgsrc.joyent.com/packages/Darwin/2014Q2/i386
DEPENDS_TARGET=	bin-install

# Build everything with -j8
MAKE_JOBS=	8

# Ignore vulnerability and license checks
ALLOW_VULNERABLE_PACKAGES=	yes
SKIP_LICENSE_CHECK=		yes

# Configure where to store distfiles, binary packages, and build areas
DISTDIR=	/work/distfiles
PACKAGES=	/work/packages
WRKOBJDIR=	/var/tmp/pkgsrc-build
{% endhighlight %}

If you want to change the build options for a particular package, first find
out which options are available with `show-options`, and then set the
particular option in `/usr/pkg/etc/mk.conf` before building:

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

$ vi /usr/pkg/etc/mk.conf
PKG_OPTIONS.nmap+=	ndiff

$ bmake install
{% endhighlight %}

## Further Information

The [pkgsrc guide](http://www.netbsd.org/docs/pkgsrc/) is packed with
information about the internals of pkgsrc, and is useful if you would like to
dig deeper and start hacking.

There are also various [pkgsrc-related posts](/tags/pkgsrc.html) on my blog
which contain various hints and tricks, though you may want to skip the
[SmartOS](http://smartos.org/)-specific sections.  I also post new branch
builds and updates there.

We hang out on Freenode `#pkgsrc`, and our mailing lists are:

* [pkgsrc-users@netbsd.org](mailto:pkgsrc-users@netbsd.org) for users
* [tech-pkg@netbsd.org](mailto:tech-pkg@netbsd.org) for developers

## Get Involved

There are over 14,000 packages in pkgsrc, so there are quite a few which
currently do not build on OSX.  The most recent bulk build report is available
[here](http://us-east.manta.joyent.com/pkgsrc/public/reports/Darwin/2014Q2/i386/20140702.1118/meta/report.html)
and shows which packages are failing along with their build logs.

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
