---
layout: post
title: Multi-architecture package support in SmartOS
tags: [pkgsrc, smartos]
---

Ever since the release of Solaris 7 back in 1998, Solaris has had the ability
to run both 32-bit and 64-bit binaries on the same machine.  Even now, 15 years
later, with much of the world 64-bit only, there are still reasons to retain
32-bit support:

 * 32-bit binaries can be faster in many cases, and if you do not need the
   additional address space afforded by the 64-bit version then there may be no
   advantage to running it.

 * Some software you depend upon may only provide a 32-bit version, or may have
   better compatability in that mode.

 * It's sometimes nice to have a hard 4GB memory limit on a runaway process
   instead of it completely trashing your machine ;)

Unfortunately, while the base [SmartOS](http://smartos.org/) platform is set up
to provide both 32-bit and 64-bit binaries, the packaging infrastructure we
use, [pkgsrc](http://www.pkgsrc.org/), has not traditionally supported building
multi-architecture packages.  This has meant we have needed to provide both
32-bit and 64-bit versions of each dataset, which is not ideal:

 * It's confusing to customers and users, who may think it applies to the
   kernel and platform version.

 * Users want the choice to be able to run 32-bit for some applications and
   64-bit for others, all on the same machine.

 * It is additional work and maintenance for us.

In order to resolve this, I have been working on providing multi-architecture
support to pkgsrc, and this work is now available for preview testing.

## Getting started

Here is a quick start guide to getting the multi-architecture dataset up and
running:

{% highlight console %}
: Fetch the dataset image and manifest files.  The image is 85MB.
$ mkdir -p /usbkey/images
$ cd /usbkey/images
$ curl -O http://pkgsrc.smartos.org/datasets/multiarch-12.4.0.dsmanifest
$ curl -O http://pkgsrc.smartos.org/datasets/multiarch-12.4.0.zfs.bz2

: Import it
$ imgadm install -m multiarch-12.4.0.dsmanifest -f multiarch-12.4.0.zfs.bz2

: Create a new zone using the dataset (change your json to suit).
$ vmadm create <<EOF
{
  "brand": "joyent",
  "image_uuid": "c7622518-5b36-11e2-bcca-2fdaa594b790",
  "max_physical_memory": 256,
  "nics": [
    {
      "nic_tag": "admin",
      "ip": "dhcp"
    }
  ]
}
EOF
{% endhighlight %}

then login and start using it as you would with any other dataset.

## Multi-architecture libraries

Libraries are reasonably straight-forward.  For most packages which provide
shared libraries, you should find both 32-bit and 64-bit libraries are
included, for example:

{% highlight console %}
$ pkg_info -L sqlite3 | grep 'so$'
/opt/local/lib/libsqlite3.so
/opt/local/lib/amd64/libsqlite3.so
{% endhighlight %}

Other directories under `lib/` should be handled correctly too, such as `.pc`
files for `pkg-config`:

{% highlight console %}
$ pkg_info -L sqlite3 | grep 'pc$'
/opt/local/lib/pkgconfig/sqlite3.pc
/opt/local/lib/amd64/pkgconfig/sqlite3.pc
{% endhighlight %}

## Multi-architecture binaries

Binaries are similar, but follow a different layout scheme, and have additional
controls to allow the user to select which architecture to use.

The basic layout is:

{% highlight console %}
$ pkg_info -L sqlite3 | grep bin
/opt/local/bin/i86/sqlite3
/opt/local/bin/amd64/sqlite3
/opt/local/bin/sqlite3
{% endhighlight %}

In order to explain this, let us look at how the base platform supports
multi-architecture binaries, using `dtrace` as an example:

{% highlight console %}
$ ls -li /usr/sbin/*/dtrace /usr/sbin/dtrace /usr/lib/isaexec
4255 -r-xr-xr-x 72 root bin 12776 Dec 28 02:38 /usr/lib/isaexec
6330 -r-xr-xr-x  1 root bin 52728 Dec 28 02:38 /usr/sbin/amd64/dtrace
4255 -r-xr-xr-x 72 root bin 12776 Dec 28 02:38 /usr/sbin/dtrace
6640 -r-xr-xr-x  1 root bin 41544 Dec 28 02:38 /usr/sbin/i86/dtrace

$ file /usr/sbin/*/dtrace /usr/lib/isaexec
/usr/sbin/amd64/dtrace: ELF 64-bit LSB executable AMD64 Version 1, dynamically linked, not stripped, no debugging information available
/usr/sbin/i86/dtrace:   ELF 32-bit LSB executable 80386 Version 1, dynamically linked, not stripped, no debugging information available
/usr/lib/isaexec:       ELF 32-bit LSB executable 80386 Version 1, dynamically linked, not stripped, no debugging information available
{% endhighlight %}

The `i86` and `amd64` hold the per-architecture binaries, and the main
`/usr/sbin/dtrace` command is a hardlink to the `/usr/lib/isaexec` wrapper (as
shown by the inode being identical).  This wrapper detects whether the running
kernel is 32-bit or 64-bit, and calls the appropriate native binary, which
nowadays will almost certainly be the 64-bit version.

For the pkgsrc implementation, I needed a way to override this behaviour so
that users could select to run the 32-bit version if so desired, without having
to munge their `$PATH`.  To do this I took a copy of `isaexec` and added it to
pkgsrc, with additional support for an `ABI` environment variable.

You can see the behaviour below with the calls to `execve()`.

* Default is to run 64-bit

{% highlight console %}
$ truss -t execve sqlite3 -version
execve("/opt/local/bin/sqlite3", 0x08047DA8, 0x08047DB4)  argc = 2
execve("/opt/local/bin/amd64/sqlite3", 0x08047DA8, 0x08047DB4)  argc = 2
3.7.15 2012-12-12 13:36:53 cd0b37c52658bfdf992b1e3dc467bae1835a94ae
{% endhighlight %}

* Set ABI=32 or ABI=i86 to run the 32-bit version

{% highlight console %}
$ ABI=32 truss -t execve sqlite3 -version
execve("/opt/local/bin/sqlite3", 0x08047D9C, 0x08047DA8)  argc = 2
execve("/opt/local/bin/i86/sqlite3", 0x08047D9C, 0x08047DA8)  argc = 2
3.7.15 2012-12-12 13:36:53 cd0b37c52658bfdf992b1e3dc467bae1835a94ae
{% endhighlight %}

Note that not all binaries have been converted to multi-architecture.  In fact,
the majority have been left as plain 32-bit binaries.  While all libraries
ultimately have to be provided for both architectures so that users can choose
to compile their own software against either, 64-bit binaries only make sense
for certain classes of software:

* Databases such as SQLite, and other servers which may require >4GB address
  space.
* Language interpreters.
* Software which provides a `foo-config` script with hardcoded references to
  `libdir`.

## Compiler support

The GCC 4.7.2 package provided has been made aware of this layout, and will add
the correct library paths depending upon the ABI you target.  For example:

{% highlight console %}
$ cat >test.c <<EOF
int main(){}
EOF

$ gcc -m32 test.c -o test32 -lsqlite3
$ ldd test32 | grep libsqlite3
        libsqlite3.so.0 =>       /opt/local/lib/libsqlite3.so.0

$ gcc -m64 test.c -o test64 -lsqlite3
$ ldd test64 | grep libsqlite3
        libsqlite3.so.0 =>       /opt/local/lib/amd64/libsqlite3.so.0
{% endhighlight %}

No additional flags or linker settings should be required (if they are, let me
know!)

## Interpreter support

For those interpreters which have been converted, their respective module
systems should be multi-architecture aware:

* Perl already had reasonable support for multi-architecture files, and all
  perl modules provided should be enabled, for example:

{% highlight console %}
$ pkgin -y in p5-Digest-SHA1
$ pkg_info -L p5-Digest-SHA1 | grep 'so$'
/opt/local/lib/perl5/vendor_perl/5.16.0/i386-solaris-thread-multi/auto/Digest/SHA1/SHA1.so
/opt/local/lib/perl5/vendor_perl/5.16.0/x86_64-solaris-thread-multi-64/auto/Digest/SHA1/SHA1.so
$ ABI=32 perl -MDigest::SHA1 -e 'print'
$ ABI=64 perl -MDigest::SHA1 -e 'print'
{% endhighlight %}

* Python is similar to Perl, but needed a lot more work to support
  multi-architecture modules.  Modules provided by pkgin should work fine, but
  there may be issues with locally-built modules - let me know!

* node is built as a multi-architecture binary, but `npm` has received no
  special handling.  This means you need to be careful not to mix-and-match
  modules.  I don't perceive this to be too much of an issue, as the node
  community appears to have settled on having one `node_modules` per
  application, but again let me know if there are better ways to handle this.

## Coverage

This work is incomplete, hence it not being available in the default datasets
yet, but a large number of packages have been converted:

 * Pretty much every package which provides shared libraries.
 * Python, Perl, Lua and node.js interpreters (and a significant number of
   modules).
 * MySQL 5.5, PostgreSQL, SQLite and DB4 databases, Apache 2.2.

Notable exceptions currently are Ruby and PHP, and I will be working on those
in due course.  There may also be a number of packages which should include
multi-architecture binaries, please let me know if I have missed any obvious
candidates.

You can raise issues against our GitHub project
[here](https://github.com/joyent/pkgsrc/issues).

Enjoy!
