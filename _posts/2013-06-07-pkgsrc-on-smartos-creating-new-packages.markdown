---
layout: post
title: pkgsrc on SmartOS - creating new packages
tags: [pkgsrc, smartos]
---

Having [set up a build
zone](/posts/pkgsrc-on-smartos-zone-creation-and-basic-builds.html) and started
[fixing packages](/posts/pkgsrc-on-smartos-fixing-broken-builds.html), the next
area we will look at is creating new packages.  For this tutorial I will use
[augeas](http://augeas.net/) as an example, as it happens to be a package I
recently created.

First, install the `pkgtools/url2pkg` package, as this massively simplifies the
task in hand.

{% highlight console %}
: If you have pkgin and binary packages available..
$ sudo pkgin in url2pkg

: ..else build from source
$ (cd pkgtools/url2pkg; bmake install)
{% endhighlight %}

Then create a new package directory, choosing the most appropriate category (in
this case `devel`), then run `url2pkg` giving it an argument of the source
tarball.

{% highlight console %}
$ mkdir devel/augeas
$ cd devel/augeas
$ url2pkg http://download.augeas.net/augeas-1.0.0.tar.gz
{% endhighlight %}

First it will open an editor session on `Makefile`.  You should customise a few
variables:

* Set `MAINTAINER` either to your email address, or to
  `pkgsrc-users@NetBSD.org` if you do not want to be the primary maintainer of
  the package.

* Write a brief one-line `COMMENT` describing what the package is.

* Set `LICENSE` to a list of the licenses the package is made available under
  (see `mk/license.mk` for an available list).

Here is what I wrote for augeas:

{% highlight make %}
# $NetBSD$

DISTNAME=	augeas-1.0.0
CATEGORIES=	devel
MASTER_SITES=	http://download.augeas.net/

MAINTAINER=	pkgsrc-users@NetBSD.org
HOMEPAGE=	http://download.augeas.net/
COMMENT=	Configuration file editing tool and library
LICENSE=	gnu-lgpl-v2

# url2pkg-marker (please do not remove this line.)
.include "../../mk/bsd.pkg.mk"
{% endhighlight %}

After writing the file and exiting the editor session, `url2pkg` will continue
and download the source tarball, create the `DESCR`, `PLIST` and `distinfo`
files, then unpack the source ready for you to start applying patches.

At this point you should edit `DESCR` and put in a few lines which describe the
package.

## Build

The general cycle will then be:

* Try building the package with `bmake`.

* If something goes wrong, modify the `Makefile` or patch the source with `pkgdiff`.

until the package builds.  Before running your first `bmake`, I would strongly
recommend adding `PKG_DEVELOPER=yes` to your `mk.conf` to turn on a lot of
additional checks.

For `augeas`, I needed a couple of things.

### Patches

The first problem I hit was:

{% highlight console %}
$ bmake
[...]
=> Checking for portability problems in extracted files
ERROR: [check-portability.awk] => Found test ... == ...:
ERROR: [check-portability.awk] configure: test "`uname`" == "SunOS" && \

Explanation:
===========================================================================
The "test" command, as well as the "[" command, are not required to know
the "==" operator. Only a few implementations like bash and some
versions of ksh support it.

When you run "test foo == foo" on a platform that does not support the
"==" operator, the result will be "false" instead of "true". This can
lead to unexpected behavior.

There are two ways to fix this error message. If the file that contains
the "test ==" is needed for building the package, you should create a
patch for it, replacing the "==" operator with "=". If the file is not
needed, add its name to the CHECK_PORTABILITY_SKIP variable in the
package Makefile.
===========================================================================
{% endhighlight %}

In this case pkgsrc gives us a very helpful message telling us about the
problem and what needs to be done to fix it (unfortunately not all problems are
handled this well!).  As `configure` is pretty important, we'll need to patch
it.

This is my usual way of handling patches (ensuring `pkgtools/pkgdiff` is
installed first):

{% highlight console %}
: Set up patches directory and some useful variables.
$ mkdir patches
$ patchdir=$(pwd -P)/patches
$ wrkdir=$(bmake show-var VARNAME=WRKSRC)

: Edit file and generate patch
$ cd $wrkdir
$ pkgvi configure
$ pkgdiff configure >$patchdir/patch-configure

: Return to pkgsrc directory, re-generate distinfo and try again.
$ cd -
$ bmake clean; bmake mps; bmake
{% endhighlight %}

This was enough to fix the `==` problem.  I then ran into other issues.

### Dependencies

Dependencies in pkgsrc are primarily handled in two ways, either with a
`buildlink` file when depending upon shared libraries or particular
infrastructure, or a simple `DEPENDS` line to pull in a required package.

The first dependency problem I hit was:

{% highlight console %}
[...]
checking readline/readline.h usability... no
checking readline/readline.h presence... no
checking for readline/readline.h... no
checking for readline in -lreadline... no
checking for library containing tgetent... -lcurses
checking for rl_initialize in -lreadline... no
configure: WARNING: readline library not found
configure: error: Could not find a working readline library (see config.log for details).
*** Error code 1
{% endhighlight %}

Ok, so this package depends upon readline.  As that is a library, we are
looking for a suitable `buildlink3.mk` file, and one of the easiest ways to do
this is:

{% highlight console %}
$ ls -1d ../../*/*readline*/buildlink3.mk
../../devel/readline/buildlink3.mk
{% endhighlight %}

To use that file, all we need to do is add an `.include` line at the bottom of
`Makefile`, just above the `bsd.pkg.mk` include.

{% highlight make %}
.include "../../devel/readline/buildlink3.mk"
.include "../../mk/bsd.pkg.mk"
{% endhighlight %}

After that, `bmake clean; bmake` to try again.  I then hit:

{% highlight console %}
[...]
checking for LIBXML... no
configure: error: Package requirements (libxml-2.0) were not met:

No package 'libxml-2.0' found
{% endhighlight %}

Ok, so similar method:

{% highlight console %}
$ ls -1d ../../*/*libxml*/buildlink3.mk
../../textproc/libxml++/buildlink3.mk
../../textproc/libxml++1/buildlink3.mk
../../textproc/libxml/buildlink3.mk
../../textproc/libxml2/buildlink3.mk
../../textproc/py-libxml2/buildlink3.mk
{% endhighlight %}

The `configure` message said libxml-2.0, so we'll pick `textproc/libxml2`.  If
you want to be more thorough you can look at the `PLIST` files for each of the
possible candidate packages - I just happen to know from experience that
`textproc/libxml2` is the one I need.

The bottom of `Makefile` now looks like this:

{% highlight make %}
.include "../../devel/readline/buildlink3.mk"
.include "../../textproc/libxml2/buildlink3.mk"
.include "../../mk/bsd.pkg.mk"
{% endhighlight %}

You'll note that we try to keep all includes other than `bsd.pkg.mk` (which is
special) sorted alphabetically.

After this, the package finally completes a `bmake` with no problems.  The
final step is to get the `install` phase working.

## Install

First we need to run a `stage-install` which will execute `make install` into a
temporary `DESTDIR`:

{% highlight console %}
$ bmake stage-install
{% endhighlight %}

This will almost certainly fail as we haven't configured the `PLIST` yet, so
pkgsrc has no idea what will be installed from this package.

{% highlight console %}
[...]
=> Automatic manual page handling
=> Generating post-install file lists
=> Checking file-check results for augeas-1.0.0
ERROR: ************************************************************
ERROR: The following files are in /var/tmp/pkgsrc-build/devel/augeas/work/.destdir/opt/pkg but not in the PLIST:
ERROR:         /var/tmp/pkgsrc-build/devel/augeas/work/.destdir/opt/pkg/bin/augparse
ERROR:         /var/tmp/pkgsrc-build/devel/augeas/work/.destdir/opt/pkg/bin/augtool
[...]
{% endhighlight %}

However, now that we have a populated `DESTDIR`, we can use the `print-PLIST`
target to generate it for us:

{% highlight console %}
$ bmake print-PLIST >PLIST
{% endhighlight %}

Finally, it's worth doing a full clean and install to ensure everything works
as expected.

{% highlight console %}
$ bmake clean
$ bmake install
[...]
=> Creating binary package /var/tmp/pkgsrc-build/devel/augeas/work/.packages/augeas-1.0.0.tgz
===> Install binary package of augeas-1.0.0
{% endhighlight %}

## buildlink

As we are installing a library package, we should provide a `buildlink3.mk`
file of our own so that other packages can depend on us correctly.  Again,
there is a package that can help with this - `pkgtools/createbuildlink`.

{% highlight console %}
$ createbuildlink >buildlink3.mk
{% endhighlight %}

This will create a template file but you should read and edit, removing the
lines marked with `XXX` and making any changes they recommend.

## Verify

Once we have a working package it's worth doing a couple of checks to make sure
everything looks ok:

{% highlight console %}
: Check the package listing looks ok
$ pkg_info -L augeas

: View the included DESCR and homepage
$ pkg_info -d augeas

: Check what the package lists as its dependencies
$ pkg_info -N augeas
{% endhighlight %}

We also should run `pkglint` (`pkgtools/pkglint`) which will perform some
sanity checks on our infrastructure files prior to us importing the package
into pkgsrc itself.  In my case it pointed out some possible issues:

{% highlight console %}
$ pkglint
WARN: PLIST:8: Packages that install libtool libraries should define USE_LIBTOOL.
WARN: PLIST:9: Packages that install libtool libraries should define USE_LIBTOOL.
ERROR: patches/patch-configure:3: Comment expected.
1 errors and 2 warnings found. (Use -e for more details.)
{% endhighlight %}

For the first issue, add `USE_LIBTOOL=yes` to `Makefile` which will ensure that
the pkgsrc libtool is used (has better support for cross-platform issues), and
for the second, add a comment at the top of the file explaining what it is for,
then re-generate `distinfo` with `bmake mps`.

After making those changes, everything looks great:

{% highlight console %}
$ pkglint
looks fine.
{% endhighlight %}

## Upstream

The final - and sometimes most challenging - part is to get your shiny new
package integrated into pkgsrc.  There are a few options:

* Find a NetBSD developer (like myself) who can review your package and put it
  straight into pkgsrc.

* Get a [pkgsrc-wip](http://pkgsrc-wip.sourceforge.net/) account and work on
 your packages there, before getting it reviewed and integrated.

* If it's somewhat niche just publish it up on GitHub or similar for people to
  use, in a similar way to what we do with
  [pkgsrc-joyent](https://github.com/joyent/pkgsrc-joyent)

## Further information

This post only scratches the surface of adding a new package.  pkgsrc provides
a huge amount of infrastructure to help get packages working on multiple
platforms, and there are lots of options available.

Certain parts of the infrastructure, like buildlink, are very complicated, and
for more in-depth information you should refer to the [pkgsrc
guide](http://www.netbsd.org/docs/pkgsrc/).

The best way is often just to look at other packages to see what they do and
re-use useful bits you find.  With 12,000 packages there is almost certainly
another package which does something similar to what you need!

Enjoy!
