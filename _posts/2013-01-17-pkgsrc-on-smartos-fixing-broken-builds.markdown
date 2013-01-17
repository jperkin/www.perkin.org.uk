---
layout: post
title: pkgsrc on SmartOS - fixing broken builds
tags: [pkgsrc, smartos]
---

This is the second in a series of posts looking at pkgsrc on SmartOS.  In the
[previous post](/posts/pkgsrc-on-smartos-zone-creation-and-basic-builds.html) I
got us up and running with building packages.  This post will focus on what to
do when the build fails.

Currently pkgsrc is able to build around 9,500 packages on SmartOS, however
pkgsrc carries over 12,000 packages in total, so there is a reasonable chance
that you will come across a package which will not produce a binary package.

Let's have a look at some of the most common failure modes and the facilities
pkgsrc provides for them to be fixed.

## Adjusting the environment

Probably the most common failures on Solaris are those caused by incorrect
compiler or linker flags, where the author of the software has not taken into
account differences across Unix platforms.  Examples include:

* the usage of __`u_int*`__ types (e.g. __`u_int32_t`__) instead of the
  portable __`uint*`__ C99 types (e.g. __`uint32_t`__).

* missing __`-lsocket -lnsl`__ when using the socket interface.

pkgsrc provides an easy way to pass __`CFLAGS`__, __`LDFLAGS`__ and other
common environment variables to the build, and these are often enough to
resolve such issues.

Taking `net/nsd` as an example:

{% highlight console %}
# cd net/nsd
# bmake package
...
gcc -I/opt/local/include -I/opt/local/include -I. -I. -O -I/opt/local/include -c ./util.c
./util.c:745:1: error: unknown type name 'u_int32_t'
*** [util.o] Error code 1
{% endhighlight %}

If we edit the Makefile and add the following line below __`CONFIGURE_ARGS`__:

{% highlight make %}
CFLAGS.SunOS+=	-Du_int32_t=uint32_t
{% endhighlight %}

then a rebuild resolves the problem and results in a binary package:

{% highlight console %}
# bmake clean
# bmake package
...
=> Creating binary package /content/packages/All/nsd-3.2.14.tgz
{% endhighlight %}

By using `CFLAGS.SunOS` rather than the global `CFLAGS` this is only performed
on systems where `uname` is `SunOS`.

We can resolve missing libraries in a similar way, taking `net/rootprobe` as an
example:

{% highlight console %}
# cd net/rootprobe
# bmake package
...
gcc -Wl,-R/opt/local/lib  rootprobe.o -o rootprobe
Undefined                       first referenced
 symbol                             in file
recv                                rootprobe.o
send                                rootprobe.o
getsockname                         rootprobe.o
socket                              rootprobe.o
getdomainname                       rootprobe.o
connect                             rootprobe.o
recvfrom                            rootprobe.o
inet_aton                           rootprobe.o
inet_ntoa                           rootprobe.o
shutdown                            rootprobe.o
ld: fatal: symbol referencing errors. No output written to rootprobe
collect2: error: ld returned 1 exit status
*** [rootprobe] Error code 1
{% endhighlight %}

Add the following to the Makefile:

{% highlight make %}
LDFLAGS.SunOS+=	-lsocket -lnsl
{% endhighlight %}

and hey presto, out comes a binary package:

{% highlight console %}
# bmake clean
# bmake package
...
gcc -lsocket -lnsl -Wl,-R/opt/local/lib  rootprobe.o -o rootprobe
/bin/rm -f cctldprobe;  ln rootprobe cctldprobe
...
=> Creating binary package /content/packages/All/rootprobe-200301.tgz
{% endhighlight %}

Not all packages can be fixed directly like this, only those which obey the
normal `${CC}` and `${LD}` environment variables, as pkgsrc creates wrappers
for those commands where it can insert these alterations.  For packages which
directly call e.g. `gcc`, some additional digging will be required to see how
the arguments can be passed.

Taking `net/3proxy` as an example, the build fails with missing socket
libraries:

{% highlight console %}
# cd net/3proxy
# bmake package
...
gcc -opop3p -Wall -O2 -pthread  sockmap.o pop3p.o sockgetchar.o myalloc.o common.o  
Undefined                       first referenced
 symbol                             in file
bind                                pop3p.o
send                                sockgetchar.o
getsockname                         common.o
accept                              pop3p.o
listen                              pop3p.o
gethostbyname                       common.o
sendto                              sockmap.o
socket                              pop3p.o
setsockopt                          pop3p.o
connect                             common.o
recvfrom                            sockmap.o
shutdown                            sockmap.o
ld: fatal: symbol referencing errors. No output written to pop3p
collect2: error: ld returned 1 exit status
*** [pop3p] Error code 1
{% endhighlight %}

but adding `LDFLAGS.SunOS+= -lsocket -lnsl` to the Makefile as before does not
resolve the problem.  Delving further into the Makefile we can see that the
build is driven from a custom Makefile rather than through autoconf/automake:

{% highlight make %}
MAKE_FILE=      Makefile.unix
{% endhighlight %}

and it is there we will need to perform the changes.  First, let's find the
work area, which we can get from the `WRKSRC` variable:

{% highlight console %}
# bmake show-var VARNAME=WRKSRC
/var/tmp/pkgsrc-build/net/3proxy/work
# cd /var/tmp/pkgsrc-build/net/3proxy/work
# ls -l Makefile.unix 
-rw-r--r-- 1 11001 10512 675 Apr 30  2005 Makefile.unix
{% endhighlight %}

Picking out the relevant bits from `Makefile.unix`:

{% highlight make %}
CC = gcc
...
CFLAGS = -Wall -g -O2 -c -pthread -D_THREAD_SAFE -D_REENTRANT -DNOODBC -DWITH_STD_MALLOC -DFD_SETSIZE=4096 -DWITH_POLL
...
LDFLAGS = -Wall -O2 -pthread
...
{% endhighlight %}

Here, the author has provided no functionality for adding to the environment,
and has instead chosen to hardcode a specific compiler and build flags,
significantly reducing the portability of their software - good luck to
Clang/LLVM or SunStudio users!

If the author had provided a way in to add to these flags, for example:

{% highlight make %}
LDFLAGS = -Wall -O2 -pthread ${USER_LDFLAGS}
{% endhighlight %}

then we could have fixed that in the main pkgsrc `Makefile` with

{% highlight make %}
MAKE_ENV+=	USER_LDFLAGS="-lsocket -lnsl"
{% endhighlight %}

or similar, however we now have no choice but to directly edit `Makefile.unix`.
Thankfully, pkgsrc provides a couple of ways to easily do this, which we will
look at over the next few sections.

## The substitution framework

The `subst` framework allows basic editing of files within the work area.  I
will show the solution for the above problem, and then discuss it:

{% highlight make %}
.include "../../mk/bsd.prefs.mk"
.if ${OPSYS} == "SunOS"
SUBST_CLASSES+=		libs
SUBST_STAGE.libs=	pre-build
SUBST_MESSAGE.libs=	Adding SunOS socket libraries
SUBST_FILES.libs=	Makefile.unix
SUBST_SED.libs=		-e '/^LDFLAGS/s/$$/ -lsocket -lnsl/'
.endif
{% endhighlight %}

Firstly, we need to limit this to SunOS systems, else we would break platforms
which do not have `libsocket` or `libnsl`.  Including `../../mk/bsd.prefs.mk`
gives us access to the `OPSYS` variable so we can test the platform we are
running on.

Next we set up the substitution framework:

* __`SUBST_CLASSES`__ creates a new class, which I have named `libs`.  This
  class name is then appended to the remaining `SUBST_*` variables to assign
  them to that class.

* __`SUBST_STAGE`__ defines the make stage when the substitution will be run,
  and should almost always be `pre-build`, to ensure it is done after any
  configuration stage which could rewrite files itself.

* __`SUBST_MESSAGE`__ is optional, and is simply a line which will be printed
  to the user when the substitution takes places.

* __`SUBST_FILES`__ is a list of files the substitution operates on.

* __`SUBST_SED`__ is the actual substitution, in the form of a `sed(1)`
  operation.  Here we append `-lsocket -lnsl` to any line beginning with
  `LDFLAGS`.  Note `$$` is required to get `make` to escape a `$`.

{% highlight console %}
# bmake clean
# bmake package
...
===> Building for 3proxy-0.5.3.11nb1
=> Adding SunOS socket libraries
...
=> Creating binary package /content/packages/All/3proxy-0.5.3.11nb1.tgz
{% endhighlight %}

Two other `subst` features you may want are:

* __`SUBST_VARS.foo= VARNAME`__ is a shortcut for the
  `-e 's,@VARNAME@,${VARNAME},g'` operation, common with autoconf-based
  packages.

* __`SUBST_FILTER_CMD.foo= <cmd>`__ allows you to run an arbitrary command,
  rather than the default of `sed`.

For more information, see the implementation in `pkgsrc/mk/subst.mk`.

## Patches

While `CFLAGS`, `LDFLAGS` and the substitution framework allow for simple
one-liner fixes, often more significant changes are required, and in those
cases the only sensible option is to create patches.  Thankfully, there are
some tools provided in pkgsrc to make this a relatively easy process.

First, let's take a broken package, `devel/bglibs`:

{% highlight console %}
# cd devel/bglibs
# bmake package
...
./ltcompile net/cork.c
net/cork.c: In function 'socket_cork':
net/cork.c:39:27: error: 'SOL_TCP' undeclared (first use in this function)
net/cork.c:39:27: note: each undeclared identifier is reported only once for each function it appears in
*** [net/cork.lo] Error code 1
{% endhighlight %}

which comes from the following function:

{% highlight c %}
/*
 * ..It is known to work on Linux (with the TCP_CORK option) and to at least
 * compile on BSD (with the TCP_NOPUSH option).  On OS's which lack either of
 * these two options, this function is essentially a no-op.
 */
int socket_cork(int sock)
{
#if defined(TCP_CORK)
  int flag = 1;
  return setsockopt(sock, SOL_TCP, TCP_CORK, &flag, sizeof flag) == 0;
#elif defined(TCP_NOPUSH)
  int flag = 1;
  return setsockopt(sock, SOL_SOCKET, TCP_NOPUSH, &flag, sizeof flag) == 0;
#else
  return 1;
#endif
}
{% endhighlight %}

Unfortunately, while SmartOS provides the `TCP_CORK` flag, it does not
understand `SOL_TCP`, and so we need to modify the test and add an additional
one.

Before doing this, we should install the `pkgtools/pkgdiff` package, which
contains a `pkgvi` wrapper.  This allows you to edit a file, and if you make
changes, it will save the resulting diff in the pkgsrc `patches` directory
ready for use.  Much easier than delving into the work area and creating
patches yourself.

{% highlight console %}
: Install via pkgin..
# pkgin in pkgdiff

: ..or through pkgsrc
# (cd ../../pkgtools/pkgdiff && bmake install)
{% endhighlight %}

Now edit the offending file:

{% highlight console %}
# pkgvi $(bmake show-var VARNAME=WRKSRC)/net/cork.c
{% endhighlight %}

This is what I changed the function to:

{% highlight c %}
int socket_cork(int sock)
{
#if defined(TCP_CORK) && defined(SOL_TCP)
  int flag = 1;
  return setsockopt(sock, SOL_TCP, TCP_CORK, &flag, sizeof flag) == 0;
#elif defined(TCP_CORK) && defined(SOL_SOCKET)
  int flag = 1;
  return setsockopt(sock, SOL_SOCKET, TCP_CORK, &flag, sizeof flag) == 0;
#elif defined(TCP_NOPUSH)
  int flag = 1;
  return setsockopt(sock, SOL_SOCKET, TCP_NOPUSH, &flag, sizeof flag) == 0;
#else
  return 1;
#endif
}
{% endhighlight %}

This still isn't ideal, and would be better converted to a proper autoconf test
where we can test functionality instead of definitions, but it will do for
example purposes.

After writing, you should get output such as:

{% highlight console %}
pkgvi: File was modified. For a diff, type:
pkgdiff "/var/tmp/pkgsrc-build/devel/bglibs/work/bglibs-1.106/net/cork.c"
{% endhighlight %}

and running the `pkgdiff` command will show you the diff.

The final step is storing the diff into a patch file, and that is accomplished
with:

{% highlight console %}
# mkpatches
# bmake mps
{% endhighlight %}

The `mkpatches` command creates a new file in the `patches` directory called
`patch-net_cork.c`, and the `bmake mps` (short for the `makepatchsum` target)
regenerates the `distinfo` file with the correct checksum for that patch.

Finally, you can rebuild

{% highlight console %}
# bmake clean
# bmake package
{% endhighlight %}

and, hey presto .. another failure!

{% highlight console %}
--- net/uncork.lo ---
net/uncork.c: In function 'socket_uncork':
net/uncork.c:30:27: error: 'SOL_TCP' undeclared (first use in this function)
net/uncork.c:30:27: note: each undeclared identifier is reported only once for each function it appears in
{% endhighlight %}

Now that you know how to fix this, I'll leave it to you to come up with a patch
;)

One final word on this, you will perhaps notice during the build some warnings:

{% highlight console %}
=> Applying pkgsrc patches for bglibs-1.106nb1
=> Ignoring patchfile /content/pkgsrc/devel/bglibs/patches/patch-ab.orig
=> Ignoring patchfile /content/pkgsrc/devel/bglibs/patches/patch-ac.orig
=> Ignoring patchfile /content/pkgsrc/devel/bglibs/patches/patch-net_cork.c.orig
{% endhighlight %}

These files are left by `mkpatches`, and to remove them you can run

{% highlight console %}
# mkpatches -c
{% endhighlight %}

Also note that both `patch-ab` and `patch-ac` changed, even though we only
modified the `net/cork.c` file.  This is due to differences in `diff(1)`
output, and is ultimately harmless.

## Summary

pkgsrc provides a number of ways to fix up broken software:

* `CFLAGS`, `LDFLAGS`, and other environment variables.

* The `subst.mk` framework for simple file changes.

* Patch files for more substantial changes.

The important thing, after using any of these features, is to feed back your
changes so that we can integrate them into pkgsrc and everyone can benefit.
Probably the easiest way to do that is simply raise an issue against [our
GitHub pkgsrc fork](https://github.com/joyent/pkgsrc/issues), and either myself
or Filip can commit the patch upstream.
