---
layout: post
title: pkgsrc on SmartOS - zone creation and basic builds
tags: [pkgsrc, smartos]
---

Our goal at [Joyent](http://www.joyent.com/) is that our binary packages for
[SmartOS](http://smartos.org/) fulfill all of our users' needs.  This isn't
always possible, however - users may want packages we do not yet provide, or
build with different options.

To satisfy those demands, it should instead be reasonably straight-forward for
users to build their own packages, and this guide hopefully provides all the
information for them to do just that.

This is the first in a series of posts, and will focus on getting pkgsrc set
up in a clean SmartOS zone and then building some packages.

## Create a build machine

For this guide I use a `base:1.8.1` SmartMachine, but any recent dataset should
be fine, and it shouldn't matter whether it's 32-bit or 64-bit.

If you are a Joyent customer:

{% highlight console %}
: Fill in your SDC details.  You can use the web interface too, if you prefer.
$ export SDC_CLI_ACCOUNT=account name
$ export SDC_CLI_IDENTITY=/path/to/ssh/key
$ export SDC_CLI_KEY_ID=key identifier
: .. or us-west-1 or us-sw-1 or eu-ams-1
$ export SDC_CLI_URL=https://us-east-1.api.joyentcloud.com

: You really really want json(1), it's awesome
$ sudo npm -g install jsontool

: Get list of 'base' datasets, we'll use the latest
$ sdc-listdatasets | json -a urn id | grep :base: | head -1
sdc:sdc:base:1.8.1 55330ab4-066f-11e2-bd0f-434f2462fada

: You can use sdc-listpackages to show available machine types.  I want one
: with good CPU performance.
$ sdc-createmachine --dataset 55330ab4-066f-11e2-bd0f-434f2462fada \
>   --name "pkgsrc-build-machine" --package "XL  8GB High CPU"
{% endhighlight %}

If you are using SmartOS:

{% highlight json %}
{
  "brand": "joyent",
  "image_uuid": "55330ab4-066f-11e2-bd0f-434f2462fada",
  "max_physical_memory": 1024,
  "quota": 24,
  "alias": "pkgsrc-build-machine",
  "hostname": "pkgsrc-build-machine",
  "nics": [
    {
      "nic_tag": "admin",
      "ip": "dhcp"
    }
  ]
}
{% endhighlight %}

Put the above json into a file, you may want to tweak some values, then

{% highlight console %}
# imgadm update
# imgadm import 55330ab4-066f-11e2-bd0f-434f2462fada
# vmadm create -f /path/to/json/file
{% endhighlight %}

Finally, log into the freshly-created zone.

## Install dependencies

First thing you'll need in the zone are build tools, so:

{% highlight console %}
# pkgin -y up
# pkgin -y in gcc47 scmgit-base
{% endhighlight %}

## Fetch pkgsrc

We maintain a fork of pkgsrc on github, which includes some additional SmartOS
fixes and improvements, so we recommend using that rather than upstream.

I put everything under `/content`, adjust to your own tastes.

{% highlight console %}
# mkdir /content
# cd /content
# git clone git://github.com/joyent/pkgsrc.git
{% endhighlight %}

Next, check out the latest stable branch.  Our naming scheme is
`joyent/release/YYYYQQ`, and the latest branch at time of writing is
`pkgsrc_2012Q4`, so:

{% highlight console %}
# cd pkgsrc
# git checkout joyent/release/2012Q4
{% endhighlight %}

If you want to be particularly adventurous, you could checkout `trunk` and get
the very latest pkgsrc code, however pkgsrc is a very fast-moving target and
you may run into unexpected breakages, and you will certainly end up rebuilding
packages very often.

## Fetch pkgsrc-wip

[pkgsrc-wip](http://pkgsrc-wip.sourceforge.net/) is a set of additional
work-in-progress packages for pkgsrc, and can be useful for trying out the
latest packages.  It is designed to be extracted directly into pkgsrc, and
we maintain a git submodule of it in our release trees, so all you need to
do, assuming you are using a `joyent/release/*` tree, is:

{% highlight console %}
# git submodule init
# git submodule update
{% endhighlight %}

This will also get you a `joyent/` directory which is a module of our
[pkgsrc-joyent](http://github.com/joyent/pkgsrc-joyent/) tree of additional
packages.

If you are on `trunk` or another tree which does not have the `wip` submodule,
you can fetch it manually with:

{% highlight console %}
# git clone git://github.com/joyent/pkgsrc-wip.git wip
{% endhighlight %}

## Configure mk.conf

The primary method of configuring pkgsrc is through the
`/opt/local/etc/mk.conf` file.  The base image comes with one populated to
handle the basic layout, but there are some additional basic variables you may
want to set prior to building your first package:

* __`DISTDIR`__ determines where source tarballs are stored, default
  `pkgsrc/distfiles`.

* __`PACKAGES`__ is where pkgsrc will store binary packages it has built,
  default `pkgsrc/packages`.

* __`WRKOBJDIR`__ is where pkgsrc performs the builds, default
  `pkgsrc/<category>/<package>/work`.

* __`ALLOW_VULNERABLE_PACKAGES`__ and __`SKIP_LICENSE_CHECK`__ should both be
  set to `yes` if you just want the package to be built, and don't care whether
  it is currently vulnerable to security issues or is released under a specific
  license.

* __`MAKE_JOBS`__ determines the argument to `make -j`, i.e. the number of
  concurrent make threads, default 1.

* __`FETCH_USING`__ sets the default program to use for fetching source code,
  defaulting to an in-tree version of NetBSD's ftp program.  Setting this to
  `curl` on SmartOS, which is included in the base platform, will avoid any
  dependencies.

* __`BINPKG_SITES`__ is a URL pointing to binary packages which can be used by
  this tree rather than building everything from source, and settings
  __`DEPENDS_TARGET`__ to `bin-install` enables using these binary packages as
  dependencies.

Thus, this is how I would configure `mk.conf`:

{% highlight console %}
# mkdir -p /content/{distfiles,packages}
# vi /opt/local/etc/mk.conf
{% endhighlight %}

{% highlight make %}
DISTDIR=	/content/distfiles
PACKAGES=	/content/packages
WRKOBJDIR=	/var/tmp/pkgsrc-build
#
ALLOW_VULNERABLE_PACKAGES=	yes
SKIP_LICENSE_CHECK=		yes
#
MAKE_JOBS=	8
#
FETCH_USING=	curl
#
# Adjust BINPKG_SITES, depending upon the dataset chosen, it should be the URL
# from /opt/local/etc/pkgin/repositories.conf without the trailing 'All'.
BINPKG_SITES=	http://pkgsrc.joyent.com/sdc6/2012Q2/i386/
DEPENDS_TARGET=	bin-install
{% endhighlight %}

## Building a package

Ok, let's get started and build a package.  pkgsrc is organised into
categories, with all packages following the `pkgsrc/<category>/<package>`
layout, and everything is driven with `bmake`, the BSD implementation of
`make(1)`.  I'm going to choose `nmap` as an example, as it will show a couple
of things I want to cover.

First, finding it.  I tend to just do a simple:

{% highlight console %}
# ls -d */*nmap*
net/nmap
{% endhighlight %}

If you want a more featured search, you can do:

{% highlight console %}
# bmake search key=nmap
{% endhighlight %}

though the first time you run this it creates the `INDEX` file it requires, and
that can take a long time.  Another option is to use the
[pkgsrc.se](http://pkgsrc.se/) web interface.

Once you have found the package, `cd` into the package directory.

{% highlight console %}
# cd net/nmap
{% endhighlight %}

Next, let's look at any options the package supports.

{% highlight console %}
# bmake show-options
{% endhighlight %}

If the package supports build options, as `net/nmap` does, you'll see
something like:

{% highlight text %}
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
{% endhighlight %}

The place to configure these options is again in `/opt/local/etc/mk.conf`, so
if you want to enable ndiff support for example, then you'd add this to
`mk.conf`:

{% highlight make %}
PKG_OPTIONS.nmap=	ndiff
{% endhighlight %}

Re-running the `show-options` command should now print:

{% highlight text %}
...
These options are currently enabled:
        inet6 ndiff
...
{% endhighlight %}

And finally, we can go ahead and build the package.  The output from this will
be long, so you may want to `tee` it to a file for reviewing:

{% highlight console %}
# bmake install 2>&1 | tee /var/tmp/nmap.log
{% endhighlight %}

Assuming this completes ok, you should note the main stages that make up a
package build:

* __`bootstrap-depends`__ comes first, and installs all the dependencies
  required for pkgsrc to get started.  `pkgtools/digest` is required to
  calculate the `SHA1` and `RMD160` checksums of the source tarball.  If we
  hadn't specified `FETCH_USING=curl` in our `mk.conf` then it's likely that
  `net/tnftp` would have been pulled in during this stage too and used to
  fetch the source.

{% highlight text %}
=> Bootstrap dependency digest>=20010302: NOT found
=> Verifying bin-install for ../../pkgtools/digest
===> Binary install for digest>=20010302
=> Installing digest>=20010302 from /content/packages/All;http://pkgsrc.joyent.com/sdc6/2012Q2/i386//All
pkg_add: Can't process file:///content/packages/All/digest*: No such file or directory
digest-20111104 successfully installed.
...
{% endhighlight %}

* __`fetch`__ and __`checksum`__ then run to download the source tarball for
  this particular package, and then verify the checksum matches that stored by
  pkgsrc, to ensure it was downloaded from a good source:

{% highlight text %}
=> Fetching nmap-6.01.tar.bz2
=> Total size: 21640157 bytes
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 20.6M  100 20.6M    0     0   699k      0  0:00:30  0:00:30 --:--:--  721k
=> Checksum SHA1 OK for nmap-6.01.tar.bz2
=> Checksum RMD160 OK for nmap-6.01.tar.bz2
{% endhighlight %}

* __`depends`__ then installs all packages required for both build and runtime
  for the package in question:

{% highlight text %}
=> Build dependency libtool-base>=2.2.6bnb3: NOT found
=> Verifying bin-install for ../../devel/libtool-base
===> Binary install for libtool-base>=2.2.6bnb3
=> Installing libtool-base>=2.2.6bnb3 from /content/packages/All;http://pkgsrc.joyent.com/sdc6/2012Q2/i386//All
libtool-base-2.2.6bnb6 successfully installed.
...
{% endhighlight %}

* __`extract`__ and __`patch`__ then unpack the source and apply any pkgsrc
  patches to the package.  The patches are located in the `patches/`
  sub-directory for each package:

{% highlight text %}
===> Extracting for nmap-6.01nb5
===> Patching for nmap-6.01nb5
{% endhighlight %}

* The bulk of the build is performed by __`configure`__ and __`build`__ which
  for most software will consist of `./configure && make`.

{% highlight text %}
===> Configuring for nmap-6.01nb5
...
checking whether NLS is requested... yes
...
Configuration complete.  Type make (or gmake on some *BSD machines) to compile.
...
===> Building for nmap-6.01nb5
...
gmake[1]: Leaving directory `/var/tmp/pkgsrc-build/net/nmap/work/nmap-6.01'
=> Unwrapping files-to-be-installed.
{% endhighlight %}

* The final steps are __`package`__ and __`install`__, firstly `package` does a
  fake install of the package to a temporary install directory and creates a
  binary package from that, and then `install` installs that binary package into
  place:

{% highlight text %}
===> Building binary package for nmap-6.01nb5
=> Creating binary package /content/packages/All/nmap-6.01nb5.tgz
===> Install binary package of nmap-6.01nb5
{% endhighlight %}

You can now verify it is installed, and start using your new software:

{% highlight console %}
# type nmap
nmap is /opt/local/bin/nmap

# nmap -p 22 localhost

Starting Nmap 6.01 ( http://nmap.org ) at 2013-01-15 15:36 UTC
Nmap scan report for localhost (127.0.0.1)
Host is up (0.00012s latency).
PORT   STATE SERVICE
22/tcp open  ssh

Nmap done: 1 IP address (1 host up) scanned in 0.11 seconds
{% endhighlight %}

## Cleanup

Once everything is working, you may want to clean up the build areas.  The
pkgsrc way of doing this is:

{% highlight console %}
# bmake clean clean-depends
{% endhighlight %}

However, if you just want to blow everything away without prejudice, you can
simply remove everything under `WRKOBJDIR`, so in my case:

{% highlight console %}
# rm -rf /var/tmp/pkgsrc-build/*
{% endhighlight %}

This should hopefully be enough to get you started.  Over the next few posts
we'll investigate some more advanced topics.  Stay tuned!
