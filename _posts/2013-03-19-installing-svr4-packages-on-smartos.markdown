---
layout: post
title: Installing SVR4 packages on SmartOS
tags: [pkgsrc, smartos, svr4]
---

Up until and including Solaris 10 the default packaging tools on Solaris were
the historical SVR4 `pkg*` commands.  First written in the early 1980s they
were standard across commercial Unix systems and provided a simplistic
interface to installing and removing binary packages.

With the introduction of IPS in OpenSolaris and beyond they have been mostly
consigned to history, however there is still software provided for Solaris
which is only available in the `.pkg` format, and thus it is useful to still
be able to handle them.

Whilst the `pkg*` tools continue to be maintained in illumos and are provided
by various distributions, they are not all provided in SmartOS.  There are a
few reasons for this:

* SmartOS has a different design to other illumos distributions, and some key
  differences such as a read-only /usr mean that some packages will simply
  break in unexpected ways.

* SmartOS is designed to be a slimmed-down distribution providing only that
  which is necessary for the majority of our users and use cases.  Including
  the SVR4 tools and metadata would bloat the system.

* SVR4 packages are often available only for older versions of Solaris, and
  whilst the excellent ABI compatability in Solaris means that the binaries
  themselves will often function correctly, the package may not support newer
  features such as SMF, or again make assumptions about the system which could
  result in irrevocable damage.

* SmartOS uses pkgsrc to manage third-party software, and we believe it is
  better to convert SVR4 packages to pkgsrc format so that all packages on the
  system can be managed with a single toolset.

However, we do continue to ship the `pkgtrans` utility with SmartOS, and this
is our gateway into converting SVR4 packages into more useful formats.  The
rest of this post will explore how we can do that.

## Unpacking SVR4 packages

Let's start with an example SVR4 package and unpack it to see what it
contains.  I'm going to use Riak, a popular open source database as the
example package.

{% highlight console %}
: Download the Solaris 10 SVR4 package from http://docs.basho.com/riak/latest/downloads/
$ curl -Os http://s3.amazonaws.com/downloads.basho.com/riak/1.3/1.3.0/solaris/10/BASHOriak-1.3.0-1-Solaris10-i386.pkg.gz

: Decompress it
$ gzip -d BASHOriak-1.3.0-1-Solaris10-i386.pkg.gz

: Use pkgtrans to unpack it into /var/tmp/BASHOriak
$ pkgtrans BASHOriak-1.3.0-1-Solaris10-i386.pkg /var/tmp all
{% endhighlight %}

SVR4 packages can contain multiple sub-packages, and so the 'all' is necessary
to unpack everything in the archive.  If we didn't specify 'all', we would
have seen:

{% highlight console %}
$ pkgtrans BASHOriak-1.3.0-1-Solaris10-i386.pkg /var/tmp

The following packages are available:
  1  BASHOriak     riak
                   (i386) 1.3.0-1

Select package(s) you wish to process (or 'all' to process
all packages). (default: all) [?,??,q]:
{% endhighlight %}

So whilst we could have specified 'riak', we can always use 'all' to avoid
having to first look at the package to see what sub-packages it contains.

We now have an unpacked package, let's go through what it contains.

### `install` sub-directory

The `install/` directory contains some files and scripts:

{% highlight console %}
$ ls -l install/
total 29
-rw-------   1 admin    deniedssh   10175 Feb 19 15:17 copyright
-rw-------   1 admin    deniedssh     214 Feb 19 15:17 depend
-rwx------   1 admin    deniedssh     438 Feb 19 15:17 i.preserve
-rwx------   1 admin    deniedssh     339 Feb 19 15:17 preinstall
-rwx------   1 admin    deniedssh     469 Feb 19 15:17 r.preserve
{% endhighlight %}

* `copyright` is self-explanatory, and is normally displayed when using the
  `pkgadd` command to let the admin know what they are agreeing to.

* `depend` is a list of other SVR4 packages that this one depends upon.  In
  this case they are:

{% highlight console %}
$ cat install/depend
# Same dependencies as Erlang
P SUNWlibmsr    Math & Microtasking Libraries (Root)
P SUNWlibms     Math & Microtasking Libraries (Usr)
P SUNWopensslr  OpenSSL (Root)
P SUNWopenssl-libraries OpenSSL Libraries (Usr)
{% endhighlight %}

  As this package is originally from Solaris 10 there is a chance that
  dependencies could cause issues.  For example, in SmartOS we have updated
  OpenSSL to 1.0.x.  Additionally, if a third-party dependency was required
  (i.e.  one not beginning with `SUNW`) then naturally you would need to
  recursively apply this entire procedure to each dependency.

* `i.preserve` and `r.preserve` are scripts executed during install (`i.`)
  and removal (`r.`).  The ones for Riak simply try to retain modified files
  from an existing install, so we will ignore these as pkgsrc handles that by
  default.

* `preinstall` is, as the name suggests, a script which is executed prior to
  installing the package.  In Riak's case it is used to create the 'riak' user
  and group if they do not already exist.

### `pkginfo`

This provides some basic metadata about the package.  The main bits we care
about are:

* `ARCH=i386`.  As long as the package only depends upon libraries provided by
  the base OS (`SUNW*`) then it shouldn't matter whether `ARCH` is 32-bit or
  64-bit.  However, if it requires third-party dependencies then you need to
  ensure that the correct ABI is provided.

* `BASEDIR=/opt`.  This is where the package would be installed by the
  `pkgadd` tool.

* `DESC=...`.  This would be output by the legacy `pkginfo` command, and we
  will re-use this text for our `pkg_info` description.

* `VERSION=1.3.0-1`.  Self-explanatory.

### `pkgmap`

This is somewhat equivalent to the pkgsrc `PLIST` file and is a record of all
the files the package provides, however it also includes file permissions and
a basic checksum:

{% highlight console %}
$ less pkgmap
: 1 112659
1 i copyright 10175 24223 1361287043
1 i depend 214 18268 1361287043
...
1 d none riak 0700 riak riak
1 d none riak/bin 0700 riak riak
1 f none riak/bin/riak 0755 riak riak 9041 51698 1361286795
...
1 e preserve riak/etc/app.config 0600 riak riak 14214 8625 1361286647
{% endhighlight %}

The last two lines, the important fields are:

* `i` is an SVR4 metadata file, `f` or `d` denote whether it is a file or a
  directory, `e` are configuration files.

* `none` means no special handling, `preserve` does just that, and the next
  field is the full path relative to `reloc/`

* `0700` and `0755` are the file/directory permissions

* `riak riak` are the user and group ownership

We will need to ensure at least the file entries are handled correctly.

### `reloc/` sub-directory

This directory contains the binaries etc. which make up the actual package.
The contents of this directory would normally be installed under `BASEDIR`
from the `pkginfo` file, so in Riak's case:

{% highlight console %}
: This..
$ ls reloc
riak
$ ls reloc/riak
bin         erts-5.9.1  etc         lib         releases

: ..would result in this
$ ls /opt/riak
bin         erts-5.9.1  etc         lib         releases
{% endhighlight %}

This concludes the examination of the SVR4 package.  Let's turn it into a
useful pkgsrc package.

## Creating pkgsrc binary package

For more information on creating binary pkgsrc packages from scratch, see
[this post](/posts/creating-local-smartos-packages.html).

### pkgsrc metadata

Create the necessary pkgsrc metadata files.

{% highlight console %}
$ mkdir /var/tmp/pkgsrc-riak
$ cd /var/tmp/pkgsrc-riak

: Standard build-info section.  Change MACHINE_ARCH to x86_64 if you are
: using a base64 image.
$ cat >build-info <<EOF
MACHINE_ARCH=i386
OPSYS=SunOS
OS_VERSION=5.11
PKGTOOLS_VERSION=20091115
EOF

: Generate comment file directly from the DESC field in pkginfo
$ awk -F= '/DESC/ {print $2}' < /var/tmp/BASHOriak/pkginfo >comment

: Generate PLIST directly from pkgmap
$ awk '$2 ~ /[ef]/ {print $4}' < /var/tmp/BASHOriak/pkgmap >plist

: For now just re-use DESC for the description file, however it would normally
: be longer
$ cp comment descr
{% endhighlight %}

### pkgsrc INSTALL script

To handle the Riak preinstall script, we will create a pkgsrc `INSTALL` script.

The existing script can be mostly used as-is, we just need to put the entire
contents of `preinstall` inside a `PRE-INSTALL` case statement so that it is
executed prior to installing the package:

{% highlight console %}
: Start with the existing preinstall script
$ cp /var/tmp/BASHOriak/install/preinstall inst

: Alter the script to create the 'riak' user/group during PRE-INSTALL, and
: after install to chown everything to 'riak' (which 
$ vi inst

PKGNAME="$1"
STAGE="$2"

case ${STAGE} in
PRE-INSTALL)
	# Existing preinstall script goes here, changing /opt references
	# to $PKG_PREFIX
	;;
{% endhighlight %}

If we recall from the `pkgmap` file, the entries there contained a user/group
that each file should be owned by, and we can handle that in the `INSTALL`
script too with a `POST-INSTALL` action:

{% highlight console %}
POST-INSTALL)
	chown -R riak:riak ${PKG_PREFIX}/riak
	;;
esac
{% endhighlight %}

### pkgsrc files

First we simply copy everything from the `reloc/` directory to a `files/`
directory we will use for pkgsrc:

{% highlight console %}
$ mkdir files
$ rsync -a /var/tmp/BASHOriak/reloc/ files/
$ chown -R root:root files
{% endhighlight %}

Next we can use the `pkgmap` file to ensure that the file modes are set
correctly with a quick and dirty script:

{% highlight bash %}
while read line
do
    set -- $line
    case "$3" in
    [def])
        chmod $5 files/$4
        ;;
    esac
done < /var/tmp/BASHOriak/pkgmap
{% endhighlight %}

### Create the package

We should now have everything necessary to create a binary package, taking the
version from the `pkgmap` file.

{% highlight console %}
$ pkg_create -B build-info -c comment -d descr -f plist -I /opt/local -i inst -p files -U riak-1.3.0.tgz
{% endhighlight %}

## Testing

If all went well then we should be able to install the package:

{% highlight console %}
$ pkg_add riak-1.3.0.tgz
{% endhighlight %}

and we will find it under `/opt/local/riak` as expected.  If we try to run the
binary, we get:

{% highlight console %}
$ /opt/local/riak/bin/riak
/opt/local/riak/bin/riak: line 30: whoami: not found
sudo doesn't appear to be installed and your EUID isn't riak
{% endhighlight %}

This nicely proves my earlier point about packages often not working unmodified
on SmartOS, in this case because `whoami` is no longer provided.  Thankfully
this is an easy fix, and we can simply change `whoami` to `id -un`.

Making that change and trying again, but this time as the riak user:

{% highlight console %}
$ su - riak
$ /opt/local/riak/bin/riak
!!!!
!!!! WARNING: ulimit -n is 1024; 4096 is the recommended minimum.
!!!!
Usage: riak {start|stop|restart|reboot|ping|console|attach|chkconfig|escript|version|getpid}
$ /opt/local/riak/bin/riak start
!!!!
!!!! WARNING: ulimit -n is 1024; 4096 is the recommended minimum.
!!!!
$ pgrep -fl riak
20628 /opt/local/riak/erts-5.9.1/bin/epmd -daemon
20650 /opt/local/riak/erts-5.9.1/bin/beam.smp -K true -A 64 -W w -- -root /opt/local/
20648 /opt/local/riak/erts-5.9.1/bin/run_erl -daemon /tmp//opt/local/riak/ /opt/local
20718 /opt/local/riak/lib/os_mon-2.2.9/priv/bin/cpu_sup
20716 /opt/local/riak/lib/os_mon-2.2.9/priv/bin/memsup
{% endhighlight %}

This seems to work about as well as one can hope, and concludes my basic example.  

## Further work

I've covered the basics here, but there are additional things you could do to
tidy up the conversion:

* Fold the `whoami` fix back into the source file and re-generate the package.

* Turn this into a real pkgsrc package, which would simplify some areas such as
  metadata and user creation.

* Come up with a script to automate a lot of this work.

* Turn the `riak` script into an SMF service.

Also note that Basho very helpfully already provide a native SmartOS package on
their download page, so this example is somewhat pointless, however I hope it
has still proven useful ;)
