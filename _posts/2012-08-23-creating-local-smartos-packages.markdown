---
layout: post
title: Creating local SmartOS packages
tags: [pkgin, pkgsrc, smartos]
---

Ok, so you have a [SmartOS](http://smartos.org/) machine set up, and are using
`pkgin` to install packages.  Now you may want to also handle your local
software using the same tools, so that you can take advantage of easily
installing and upgrading packages.  This post describes how you can do this.

We will be creating a hypothetical package `meminfo`, containing a script of
the same name which prints basic memory information, and just enough metadata
for it to be understood by the packaging tools.  This guide assumes you are
running a standard dataset which includes packaging tools in `/opt/local/sbin`,
that is:

{% highlight console %}
$ /opt/local/sbin/pkg_info
{% endhighlight %}

should give you a list of currently installed packages.

### Files to install

First, let's start in a clean directory, and then create a `files`
sub-directory which will hold the files we want to package.  The files in this
directory will be installed relative to the packaging prefix, which for most
SmartOS installs will be `/opt/local`.

{% highlight console %}
$ mkdir package
$ cd package
$ mkdir -p files/bin
{% endhighlight %}

Now we create the `meminfo` script.  You will probably just copy your binaries
into place at this stage.

{% highlight console %}
$ vi files/bin/meminfo
{% endhighlight %}

{% highlight bash %}
#!/usr/bin/bash
#
# This is just a subset of 'sm-summary' from the 'smtools' package.
#
SM_UUID=$(zonename);
SM_ID=$(zoneadm list -p | awk -F: '{ print $1 }');
SM_MEMCAP=$(kstat -p -c zone_caps -n lockedmem_zone_${SM_ID} -s value | awk '{print $2/1024/1024 }');
SM_MEMUSED=$(prstat -Z -s rss 1 1 | awk -v zone=${SM_UUID} '$8 ~ zone { printf("%d", $4 ) }');
SM_MEMFREE=$(echo "${SM_MEMCAP}-${SM_MEMUSED}" | bc);
cat <<EOF
Memory (RSS) Cap    ${SM_MEMCAP}M
Memory (RSS) Used   ${SM_MEMUSED}M
Memory (RSS) Free   ${SM_MEMFREE}M
EOF
{% endhighlight %}

Ensure the script is executable!

{% highlight console %}
$ chmod +x files/bin/meminfo
{% endhighlight %}

Finally for this part, generate a `packlist` file which simply contains a list
of files we want packaged, relative to the `files` directory:

{% highlight console %}
$ (cd files; find * -type f -or -type l | sort) >packlist
{% endhighlight %}

The `packlist` file supports many directives which are lines beginning with
`@<cmd>`.  These let you do things such as change file permissions once the
file has been installed.  See the 'PACKING LIST DETAILS' section of
[`pkg_create(1)`](http://netbsd.gw.com/cgi-bin/man-cgi?pkg_create) for more
information.

### Package metadata

In order to successfully create a package, we need a few metadata files which
describe the package.

#### build-info

This file contains basic information about the package, and is primarily used
to ensure that the package can be installed on the target machine.  The minimum
information required is:

* `MACHINE_ARCH`.  On SmartOS this is either `i386` or `x86_64` depending upon
  whether you chose a `base/smartos` or `base64/smartos64` dataset.  Attempting
  to install a package intended for one architecture with package tools built
  for a different architecture will work due to SmartOS being able to run both
  32-bit and 64-bit applications, but you will get warnings when installing.
* `OPSYS`.  On SmartOS this is `SunOS`, i.e. the output of `uname -s`.
* `OS_VERSION`.  On SmartOS this is `5.11`, i.e. the output of `uname -r`.
* `PKGTOOLS_VERSION`.  An integer describing the version of the `pkg_install`
  tools required to understand this package.  At the current time pkgsrc sets
  a base version of `20091115` so just use this.

The easiest way to generate this file is simply to get it from an existing
package, for example:

{% highlight console %}
$ pkg_info -X pkg_install \
  | egrep '^(MACHINE_ARCH|OPSYS|OS_VERSION|PKGTOOLS_VERSION)' >build-info
$ cat build-info
MACHINE_ARCH=i386
OPSYS=SunOS
OS_VERSION=5.11
PKGTOOLS_VERSION=20091115
{% endhighlight %}

#### comment

This is a short string describing the package which is shown in the default
`pkg_info` or `pkgin list` output.  Keep this short, preferably under 60
characters, so that it displays correctly in 80-column terminals.

{% highlight console %}
$ echo "Show basic memory information on SmartOS" >comment
{% endhighlight %}

#### description

This is a longer multi-line description of the package which is output by
`pkg_info <package name>` or `pkgin pkg-descr <package name>`.  Format this to
80-columns.

{% highlight console %}
$ cat >description <<EOF
meminfo prints basic information about available memory on a SmartOS machine,
listing the total memory size, used, and free.  The information provided
should be understood in light of how memory is used and reported on SmartOS,
for more information refer to:

http://wiki.smartos.org/display/DOC/About+Memory+Usage+and+Capping
EOF
{% endhighlight %}

So we should now have:

{% highlight console %}
build-info          # basic package information
comment             # one-line comment
description         # multi-line comment
files/bin/meminfo   # the file we wish to package
packlist            # package listing
{% endhighlight %}

### Create the package

We now have enough information to create a basic package.  The magic invocation
to perform the operation is:

{% highlight console %}
$ pkg_create -B build-info -c comment -d description -f packlist \
  -I /opt/local -p files -U meminfo-1.0.tgz
{% endhighlight %}

The `-B`, `-c`, `-d` and `-f` arguments simply pull in the metadata files we've
written.

The `-I` argument specifies the destination prefix.  As we are creating a
package outside of this prefix we need to tell `pkg_create` of the ultimate
destination.

The `-p` argument is used in conjunction with `-I` to tell pkg_create where our
files to be packaged can be found.

The `-U` argument means we should just create the package, and not register it.

And finally, we provide the package file.  The packaging tools understand
version numbers, so we can just provide the file name and it will determine the
package name and version from that.

To verify the package, you can run:

{% highlight console %}
$ pkg_info -X meminfo-1.0.tgz
{% endhighlight %}

{% highlight bash %}
PKGNAME=meminfo-1.0
COMMENT=Show basic memory information on SmartOS
MACHINE_ARCH=i386
OPSYS=SunOS
OS_VERSION=5.11
PKGTOOLS_VERSION=20091115
FILE_NAME=meminfo-1.0.tgz
FILE_SIZE=922
DESCRIPTION=meminfo prints basic information about available memory on a SmartOS machine,
DESCRIPTION=listing the total memory size, used, and free.  The information provided
DESCRIPTION=should be understood in light of how memory is used and reported on SmartOS,
DESCRIPTION=for more information refer to:
DESCRIPTION=
DESCRIPTION=http://wiki.smartos.org/display/DOC/About+Memory+Usage+and+Capping

{% endhighlight %}

### Installing

For a single machine, you can now simply install the package with:

{% highlight console %}
$ pkg_add meminfo-1.0.tgz
{% endhighlight %}

If you want to publish the package so that it is available to `pkgin` you need
to create a `pkg_summary` file and put it alongside the package for download.
This file is usually compressed to speed things up, and `pkgin` supports both
`.gz` and `.bz2`.

{% highlight console %}
$ pkg_info -X meminfo-1.0.tgz | gzip -9 >pkg_summary.gz
{% endhighlight %}

For example purposes I will simply use file://, but of course you can use
http:// instead if you put the packages and pkg_summary file somewhere
accessible:

{% highlight console %}
$ mkdir /var/tmp/packages
$ cp meminfo-1.0.tgz pkg_summary.gz /var/tmp/packages
{% endhighlight %}

Add this repository to `pkgin` and reload:

{% highlight console %}
$ echo "file:///var/tmp/packages" >>/opt/local/etc/pkgin/repositories.conf
$ sudo pkgin -fy up
{% endhighlight %}

Now the package should show up:

{% highlight console %}
$ pkgin avail | grep meminfo
meminfo-1.0          Show basic memory information on SmartOS
{% endhighlight %}

and be installable:

{% highlight console %}
$ sudo pkgin -y install meminfo
$ /opt/local/bin/meminfo
Memory (RSS) Cap    8192M
Memory (RSS) Used   92M
Memory (RSS) Free   8100M
{% endhighlight %}

This covers the basics and should be enough to get started.  As mentioned,
there are many other options available, and I suggest that if you need
additional functionality you take a look at the
[`pkg_create`](http://netbsd.gw.com/cgi-bin/man-cgi?pkg_create) manual page, or
simply use `pkg_info -X` on more complicated packages to see what they do.
