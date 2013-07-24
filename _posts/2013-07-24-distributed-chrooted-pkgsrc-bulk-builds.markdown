---
layout: post
title: Distributed chrooted pkgsrc bulk builds
tags: [pbulk, pkgsrc, smartos]
---

Once you are up and running with pkgsrc, one of the most common requests is a
way to automatically build a number of packages, either a specific list plus
their dependencies, or everything currently available.

There are a number of ways to accomplish this, but for this tutorial I will
concentrate on `pbulk`, as it is used by a number of pkgsrc developers, and 
has support for distributed and chrooted builds.

In this example I am building a set of `pkgsrc-2013Q2` packages, and I have
tested it on:

* Linux
* OSX
* SmartOS

Please let me know if it doesn't work correctly on your platform.

## Layout

First, have a think about where you will store pkgsrc, source tarballs,
packages, etc.  I put everything under `/content` which makes it easy to then
mount just that directory and have everything below it available:

* `/content/bulklog` is where pbulk saves the per-package build logs
* `/content/distfiles` is where source tarballs are kept
* `/content/mk` contains some `make` fragment files for configuration
* `/content/packages` is the top-level directory of binary packages
* `/content/pkgsrc` is where pkgsrc is located
* `/content/scripts` to hold some miscellaneous scripts

Pre-create some required directories:

{% highlight console %}
$ mkdir -p /content/{distfiles,mk,packages/bootstrap,scripts}
{% endhighlight %}

Then write a couple of `mk.conf` files which will be used by the packaging tools.

`/content/mk/mk-generic.conf`:

{% highlight make %}
ALLOW_VULNERABLE_PACKAGES=	yes
SKIP_LICENSE_CHECK=		yes
DISTDIR=			/content/distfiles

# If your system has a native curl, this avoids building nbftp
FAILOVER_FETCH=		yes
FETCH_USING=		curl

# Change this to a closer mirror
MASTER_SITE_OVERRIDE=	ftp://ftp2.fr.NetBSD.org/pub/NetBSD/packages/distfiles/

# Tweak this for your system, though take into account how many concurrent
# chroots you may want to run too.
MAKE_JOBS=		4
{% endhighlight %}

`/content/mk/mk-pbulk.conf`:

{% highlight make %}
.include "/content/mk/mk-generic.conf"

PACKAGES=	/content/packages/2013Q2/pbulk
WRKOBJDIR=	/var/tmp/pkgbuild
{% endhighlight %}

`/content/mk/mk-pkg.conf`:

{% highlight make %}
.include "/content/mk/mk-generic.conf"

PACKAGES=	/content/packages/2013Q2/x86_64
WRKOBJDIR=	/home/pbulk/build
{% endhighlight %}

## Get pkgsrc

{% highlight console %}
$ cd /content
{% endhighlight %}

Either use git..

{% highlight console %}
$ git clone -b pkgsrc_2013Q2 https://github.com/joyent/pkgsrc.git
{% endhighlight %}

..or CVS

{% highlight console %}
$ cvs -d anoncvs@anoncvs.netbsd.org:/cvsroot co -rpkgsrc-2013Q2 -P pkgsrc
{% endhighlight %}

At the present time (`2013Q2`) there are a couple of patches you need to apply,
one for mksandbox to support some additional features, and one for pbulk to
support chroots and a couple of other bits we've developed at Joyent.

{% highlight console %}
$ cd pkgsrc
$ curl -s http://www.netbsd.org/~jperkin/mksandbox-1.3.diff | patch -p0
$ curl -s http://www.netbsd.org/~jperkin/pbulk-joyent.diff | patch -p0
{% endhighlight %}

## Build pbulk

pbulk needs to be installed to its own prefix, from where it will manage the
main build.

{% highlight console %}
$ cd bootstrap
$ ./bootstrap --abi=64 --prefix=/usr/pbulk --mk-fragment=/content/mk/mk-pbulk.conf
$ ./cleanup; cd ..
{% endhighlight %}

Then build the necessary pacakges

{% highlight console %}
$ PATH=/usr/pbulk/sbin:/usr/pbulk/bin:$PATH
$ cd pkgtools/pbulk
$ bmake package-install
$ cd ../mksandbox
$ bmake package-install
{% endhighlight %}

It is recommended that builds are done as an unprivileged user, which is normally
named `pbulk`, so now would be a good time to create that user, usually with
something like this:

{% highlight console %}
$ groupadd -g 500 pbulk
$ useradd -u 500 -g 500 -c 'pbulk user' -s /bin/bash -m pbulk
{% endhighlight %}

Check the `useradd/groupadd` syntax for your system.  The user can be set to
`no-password`, it will only be used via `su` from the root user.

## Set up chroot

Next, check that the mksandbox script works on your system.  It is designed to
be cross-platform, but on certain systems (e.g. OSX) there is no native support
for loopback mounts, and so you will first need to configure NFS in order to
share system directories to the chroot, usually with `/ -alldirs -maproot=root`
in `/etc/exports` then `nfsd enable`.

{% highlight console %}
$ mkdir /chroot

: This command should create the chroot under /chroot/test
$ mksandbox --rodirs=/usr/pbulk --rwdirs=/content --without-pkgsrc /chroot/test

: This should execute a shell inside the chroot.  Check that directories are
: mounted as expected, and that you can't e.g. write to a read-only file system.
$ /chroot/test/sandbox 

: This should unmount the chroot mounts
$ /chroot/test/sandbox umount

: Test that there are no left-over mounts before removing, else you may delete
: files on a read-write mount!  This should return no results.
$ mount -v | grep /chroot/test/

$ rm -rf /chroot/test
{% endhighlight %}

Once you are happy the chroot is working as expected, write a couple of wrapper
scripts to create and delete them with an optional argument with the name of
the chroot, which will be used by pbulk.  Below are the scripts I use.

`/content/scripts/mksandbox`:

{% highlight bash %}
#!/bin/sh

chrootdir=$1; shift

while true
do
	# XXX: limited_list builds can recreate chroots too fast.
	if [ -d ${chrootdir} ]; then
		echo "Chroot ${chrootdir} exists, retrying in 10 seconds or ^C to quit"
		sleep 10
	else
		break
	fi
done

/usr/pbulk/sbin/mksandbox --without-pkgsrc \
    --rodirs=/usr/pbulk --rwdirs=/content ${chrootdir} >/dev/null 2>&1
mkdir -p ${chrootdir}/home/pbulk
chown pbulk:pbulk ${chrootdir}/home/pbulk
{% endhighlight %}

`/content/scripts/rmsandbox`:

{% highlight bash %}
#!/bin/sh

chrootdir=`echo $1 | sed -e 's,/$,,'`; shift

if [ -d ${chrootdir} ]; then
	#
	# Try a few times to unmount the sandbox, just in case there are any
	# lingering processes holding mounts open.
	#
	for retry in 1 2 3
	do
		${chrootdir}/sandbox umount >/dev/null 2>&1
		mounts=`mount -v | grep "${chrootdir}/"`
		if [ -z "${mounts}" ]; then
			rm -rf ${chrootdir}
			break
		else
			sleep 5
		fi
	done
fi
{% endhighlight %}

## Build pkg bootstrap

Next step is to build the bootstrap for the target packages, i.e. the main
prefix you will be using.  Again we use the bootstrap script, but here you
may want to tweak the settings - check the pkgsrc guide or the `--help`
output for more information.

If the prefix you want to build for (i.e. `/usr/pkg`) is already in use on the
system, simply do the bootstrap inside a chroot.

I use something like this:

{% highlight bash %}
$ /content/scripts/mksandbox /chroot/build-bootstrap
$ /chroot/build-bootstrap/sandbox
$ cd /content/pkgsrc/bootstrap

: Use the defaults of /usr/pkg.  --gzip-binary-kit is important, it is the
: tarball that pbulk will use for builds.
$ ./bootstrap \
    --abi=64 \
    --gzip-binary-kit=/content/packages/bootstrap/bootstrap-2013Q2-pbulk.tar.gz \
    --mk-fragment=/content/mk/mk-pkg.conf
$ ./cleanup
$ exit

$ /content/scripts/rmsandbox /chroot/build-bootstrap
{% endhighlight %}

## Configure pbulk

Now we're finally ready to configure pbulk.  There is a single configuration file
you need to edit, and I will show the changes I have made to it.

{% highlight bash %}
$ diff /usr/pbulk/share/examples/pbulk/pbulk.conf /usr/pbulk/etc/pbulk.conf
{% endhighlight %}

This section adds a `ulimit` to stop runaway processes from hanging the build.

{% highlight diff %}
2a3,6
> # Limit processes to an hour of CPU time.  Anything which takes longer than
> # this is most probably broken.
> ulimit -t 3600
>
{% endhighlight %}

This section configures the location of the bulk build report.  I upload my
results to Joyent's [Manta](http://www.joyent.com/products/manta) object store
as it allows arbitrary storage plus distributed Unix queries on the data at a
later time.

{% highlight diff %}
11c15
< base_url=http://www.pkgsrc-box.org/reports/current/DragonFly-1.8
---
> base_url=http://us-east.manta.joyent.com/pkgsrc/public/reports/Darwin/2013Q2/x86_64
{% endhighlight %}

Turn on `reuse_scan_results`, it makes subsequent runs faster.

{% highlight diff %}
14c18
< reuse_scan_results=no
---
> reuse_scan_results=yes
{% endhighlight %}

In this example I am using a single host which will perform concurrent builds
inside chroots, and so I need to unset `scan_clients` and `build_clients` and
set `master_ip` to localhost.

If you have multiple hosts, simple set `master_ip` to a public address, and add
the list of slave IP addresses to `*_clients`.  They will need to be accessible
via SSH as root from the master, and will need to have their own installs of
`/usr/pbulk` as well as sharing the same `/content` mount as the master, most
likely over NFS.

If you wish to completely disable any concurrency or distributed builds, set
`master_mode=no`, though note that the build with then run completely
single-threaded and will be much slower.

{% highlight diff %}
22,24c26,28
< master_ip=192.168.75.10
< scan_clients="192.168.75.21 192.168.75.22 192.168.75.23 192.168.75.24"
< build_clients="192.168.75.21 192.168.75.22 192.168.75.23 192.168.75.24"
---
> master_ip=127.0.0.1
> scan_clients=""
> build_clients=""
{% endhighlight %}

If you wish to publish to Manta, here are the settings you will need.  I have
installed a local copy of the Manta tools to `/content/manta`, as the upload
script will need them.

{% highlight diff %}
28a33,39
> # Manta upload settings
> MANTA_USER="pkgsrc"
> MANTA_KEY_ID="40:b7:2e:b5:de:04:17:78:35:0b:d8:72:b9:da:8d:0e"
> MANTA_URL="https://us-east.manta.joyent.com"
> MANTA_PATH="/usr/pbulk/bin:/content/manta/node_modules/.bin"
> report_manta_target="/pkgsrc/public/reports/Darwin/2013Q2/x86_64"
>
{% endhighlight %}

Configure the location where to rsync packages to and where to send the report.
If you are not using Manta, then you will want to set `report_rsync_target` to
an appropriate location.

{% highlight diff %}
33c44
< pkg_rsync_target="pkgsrc@192.168.75.1:/public/packages/current/DragonFly-1.8"
---
> pkg_rsync_target="pkgsrc.joyent.com:/packages/Darwin/2013Q2/x86_64"
36,37c47,48
< report_subject_prefix="pkgsrc"
< report_recipients="pkgsrc-bulk@netbsd.org"
---
> report_subject_prefix="pkgsrc-2013Q2"
> report_recipients="jperkin@joyent.com"
{% endhighlight %}

Where to find the `/usr/pkg` bootstrap tarball:

{% highlight diff %}
41c52
< bootstrapkit=/usr/pkgsrc/bootstrap/bootstrap.tar.gz
---
> bootstrapkit=/content/packages/bootstrap/bootstrap-2013Q2-pbulk.tar.gz
{% endhighlight %}

Configure build chroots.  Here we set the paths to the `mksandbox` and
`rmsandbox` scripts we created earlier, and provide a basename of the chroot
directory.  By setting `chroot_dir=/chroot/pkgsrc-2013Q2`, pbulk will actually
create `/chroot/pkgsrc-2013Q1-build-{1,2,3,4}` and
`/chroot/pkgsrc-2013Q1-scan-{1,2,3,4}`.

You will want to experiment with the tradoffs between `MAKE_JOBS` and the
number of chroots.  Generally it will be better to have more chroots compared
to an increase in `MAKE_JOBS`, as certain parts of the build will be single
threaded anyway (e.g. large configure scripts).  However, you also need to be
aware of the increased disk I/O caused by too many chroots.

As long as you have everything correctly shared, there is nothing stopping you
using distributed hosts _and_ chroots, and it is highly recommended if you can
as clearly it provides the best performance.  With such a setup, at Joyent we
are able to do full bulk builds of all 12,000 packages in pkgsrc in under 12
hours.

{% highlight diff %}
46a58,64
> # Chroot scripts.
> chroot_create=/content/scripts/mksandbox
> chroot_delete=/content/scripts/rmsandbox
> chroot_dir=/chroot/pkgsrc-2013Q2
> build_chroots=4
> scan_chroots=4
>
{% endhighlight %}

Finally, configure paths to the ones we have chosen.

{% highlight diff %}
74,75c92,93
< bulklog=/bulklog
< packages=/packages
---
> bulklog=/content/bulklog
> packages=/content/packages/2013Q2/x86_64
77c95
< pkgsrc=/usr/pkgsrc
---
> pkgsrc=/content/pkgsrc
{% endhighlight %}

One option not mentioned above is `limited_list`.  If you only want to build a
subset of packages rather than run a full bulk build, simply set `limited_list`
to a file containing paths to packages you want.  It is worth doing this
initially anyway, just to check that everything is working fine, e.g.:

{% highlight console %}
$ cat >/content/mk/pkglist <<EOF
sysutils/coreutils
EOF
{% endhighlight %}

{% highlight diff %}
45c45
< #limited_list=/limited_list
---
> limited_list=/content/mk/pkglist
{% endhighlight %}

## Run the bulk build

Assuming everything was done correctly, it should now just be a matter of
running the bulkbuild.  If you have set the `chroot_*` variables then this will
run chrooted at the appropriate places, so that your host system's `/usr/pkg`
is not affected.

{% highlight console %}
$ bulkbuild
{% endhighlight %}

One of the benefits of the Joyent patch is that it adds support for different
configuration files, so if you really want to you can run concurrent instances
of pbulk.  Just write separate `pbulk.conf` files and then pass them as
arguments to `bulkbuild`.  Again, we use this to run multiple builds across the
same hosts, all thanks to the chroot support.

{% highlight console %}
$ bulkbuild pbulk-32bit.conf
$ bulkbuild pbulk-64bit.conf
{% endhighlight %}

## Caveats

There are some known issues, I will document them here as they are found.

### OSX chroot DNS resolution

On OSX, name resolution is broken inside a chroot.  This is due to
mDNSResponder being used for DNS lookups, which relies on the
`/var/run/mDNSResponder` UNIX socket.  Unfortunately, making that socket
available in the chroot (either by mounting or creating a proxy with `socat`)
does not fix the issue, so I would welcome input on this.

For now you need to set `MASTER_SITE_OVERRIDE` and then ensure that the IP
address for that mirror is set in `/etc/hosts`.

### Chroot creation race conditions

As you can see in my example `mksandbox` script, I have to work around a race
condition where a previous scan run may still be cleaning up whilst a new one
is starting.  For now I am simply sleeping until the chroot is free, but this
should be fixed properly, probably with process groups and waiting for them to
complete.
