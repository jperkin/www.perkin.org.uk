---
layout: post
title: How to build MySQL releases
tags: [mysql]
---

One of the major benefits from the [CMake
work](http://forge.mysql.com/wiki/CMake) available in MySQL 5.5 is that in the
MySQL Release Engineering team we have been able to make it easy for users and
developers to build MySQL exactly as we do for the official releases.  For too
long there has been a disconnect between the binaries produced as part of a
regular '`./configure; make`' build and what we ship to users and customers.

We're still not exactly where we want to be, there are still some parts which
need to be integrated into the server tree, but for now it's relatively
straightforward to build exactly as we do.

Here are the instructions, using the `mysql-5.5.6-rc.tar.gz` source tarball as an
example.

## tar.gz

These are the generic instructions to build a tarball release.  Note that we
make use of CMake's out-of-srcdir support to

* ensure the source directory is kept pristine
* allow us to easily build both debug and release binaries, and package them together

{% highlight bash %}
#!/bin/sh

tar -zxf mysql-5.5.6-rc.tar.gz

# Build debug binaries first, they are picked up in the final 'make package'
mkdir debug
(
  cd debug
  cmake ../mysql-5.5.6-rc -DBUILD_CONFIG=mysql_release -DCMAKE_BUILD_TYPE=Debug
  make VERBOSE=1
)

# Build release binaries and create final package
mkdir release
(
  cd release
  cmake ../mysql-5.5.6-rc -DBUILD_CONFIG=mysql_release
  make VERBOSE=1 package
)
{% endhighlight %}

Assuming everything goes ok, you should end up with a tarball in the `release/`
directory.

Some platforms require extra flags to be specified on the CMake command line to
ensure the correct compiler etc is used.  Here are some that we use.

### Avoid libstdc++ dependancy

In order to create 'generic' binaries, on GCC platforms we compile using
`CXX=gcc`.  This avoids `libstdc++` being pulled in, and means that the server
will run across a larger range of releases as you do not rely on having the
exact version of `libstdc++` installed by your system package manager.

Paste this before running cmake.

{% highlight console %}
# CXXFLAGS is required to trick CMake into believing it is a C++ compiler
$ CXX=gcc; CXXFLAGS="-fno-exceptions"; export CXX CXXFLAGS
{% endhighlight %}

### Specify target architecture

On systems which support multiple targets, you can specify exactly which one
you want, rather than relying on the OS default.  These strings are meant to be
added to the cmake command lines above.

* OSX

{% highlight console %}
$ -DCMAKE_OSX_ARCHITECTURES="i386"    # 32bit
$ -DCMAKE_OSX_ARCHITECTURES="x86_64"  # 64bit
{% endhighlight %}

* GCC/Sun Studio

{% highlight console %}
$ -DCMAKE_C_FLAGS="-m32" -DCMAKE_CXX_FLAGS="-m32"  # 32bit
$ -DCMAKE_C_FLAGS="-m64" -DCMAKE_CXX_FLAGS="-m64"  # 64bit
{% endhighlight %}

* HP/UX

{% highlight console %}
$ -DCMAKE_C_FLAGS="+DD64" -DCMAKE_CXX_FLAGS="+DD64"
{% endhighlight %}

## RPM

We've spent a lot of time improving the RPM builds too.  Previously some of the
configuration was only available in the commercial RPM builds, but now we have
merged them into the community version.

{% highlight bash %}
#!/bin/sh

mkdir -p rpm/{BUILD,RPMS,SOURCES,SPECS,SRPMS} tmp

# Create spec file.
# XXX: We should probably just include this in the source tarball.
tar -zxf mysql-5.5.6-rc.tar.gz
(
  mkdir bld; cd bld
  cmake ../mysql-5.5.6-rc
)

cp bld/support-files/*.spec rpm/SPECS
cp mysql-5.5.6-rc.tar.gz rpm/SOURCES

rpmbuild -v --define="_topdir $PWD/rpm" --define="_tmppath $PWD/tmp" \
 -ba rpm/SPECS/mysql.5.5.6-rc.spec
{% endhighlight %}

You should end up with nice shiny RPMs in `rpm/RPMS`.  One thing to note is
that the RPM spec no longer runs the test suite as part of the build, so you
will need to run that separately.  On the plus side, you get your RPMs much
quicker.

Another nice thing about the improved RPM spec is that you can now build
targetted distribution RPMs, as we do.  These have extra dependancy information
in them tailored to the target distribution.  Currently the spec file supports
the distributions we build on, but we will accept patches for others.

To enable this, use:

{% highlight console %}
$ rpmbuild -v --define="distro_specific 1" ...
{% endhighlight %}

## Windows

Our Windows builds have relied on CMake since MySQL 5.0, but the procedure has
still changed to ensure that you can build as we do.  These instructions use
`cmd.exe` but you can use the Visual Studio front end if you prefer.

{% highlight bat %}
unzip mysql-5.5.6-rc.zip

rem There is no separate 'debug' directory on Windows, as the CMake
rem infrastructure doesn't yet know to pull files in from there on Windows.
md release
cd release

rem Choose your target architecture, 32bit
set VSTARGET=Visual Studio 9 2008
rem or 64bit
set VSTARGET=Visual Studio 9 2008 Win64

cmake ..\mysql-5.5.6-rc -DBUILD_CONFIG=mysql_release \
 -DCMAKE_BUILD_TYPE=Debug -G "%VSTARGET%"

devenv MySql.sln /build Debug

cmake ..\mysql-5.5.6-rc -DBUILD_CONFIG=mysql_release \
 -DCMAKE_BUILD_TYPE=RelWithDebInfo -G "%VSTARGET%"
{% endhighlight %}

You can now choose which type of package to create.  5.5 includes new code to
create minimal MSI packages, these should work ok, and only differ from the
official MySQL MSI packages in that they do not include the instance config
wizard.

To create the MSI packages you will need to install
[WiX](http://wix.codeplex.com/).

{% highlight bat %}
rem Standard zip package
devenv MySql.sln /build RelWithDebInfo /project package

rem Full MSI package
devenv MySql.sln /build RelWithDebInfo /project msi

rem 'Essentials' MSI package
devenv MySql.sln /build RelWithDebInfo /project msi_essentials
{% endhighlight %}

Assuming everything goes ok, you should have some packages in the `release\`
directory.

## Work still to be done

We still have a number of scripts only available internally, for example those
we use to create SVR4, DMG and DEPOT packages.  However, we are looking to
integrate these into the MySQL Server source tree so that all users can benefit
from them.

Enjoy!
