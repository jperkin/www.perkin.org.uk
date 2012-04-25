---
layout: post
title: Creating chroots for fun and MySQL testing
tags: [chroot, mysql]
---

Virtualisation is all the rage today, however there are still a few cases where
good old-fashioned Unix chroot is still applicable, and testing MySQL across
multiple platforms and architectures is one of those cases.

At Oracle we do full automated package verification testing of our MySQL server
binaries prior to release, which attempts to install the package, start the
server, run some functionality testing, then uninstall.  It is of course highly
desirable that the testing environment this is performed in is as close to a
clean install of the target operating system as possible, to avoid problems
such as our packages depending upon some local changes or packages we may have
installed which won't be available on a customer system.

Given the large number of platforms and architectures that MySQL supports,
going the virtualisation route would mean having to use many different
products: VirtualBox for x86, zones for SPARC, qemu for ia64/PA-RISC/others (if
it even supports them), and this gets complicated quickly and is not very
maintainable.  Thus I chose to use chroot as much as possible.  In addition, it's
much faster and less intensive on resources to use a chroot than boot up an
entire OS image each time.

I built all images directly from the original installation images (DVD, ISO,
RPM, etc), to ensure that there was no contamination from our build environment
or local install scripts in the image – they should be as close to what a
normal user or customer will be running in their setup.  From the install image,
the packages are installed to a temporary directory, some final modifications
are made, then the directory is tarred up ready to be extracted by the test
framework and used.

Here are some operating system specific examples, which set up an extracted
chroot image into `${CHROOTDIR}`.  There may be additional steps required to
get a fully functioning chroot, such as copying device files (`/dev/zero` and
`/dev/null` are usually the minimum requirements) and adding users.

## FreeBSD

FreeBSD 7 and 8 come as a number of sets in tar format, and for our purposes we
only need to extract the base set.  You may wish to add more sets if you want to
use your chroot for building packages:

{% highlight bash %}
#!/bin/sh
mdunit=$(mdconfig -a -t vnode -o readonly -f /path/to/dvd1/of/freebsd.iso)
mount_cd9660 /dev/${mdunit} /mnt
cat /mnt/*/base/base.?? | tar -xpzf - -C ${CHROOTDIR}
umount /mnt
mdconfig -d -u ${mdunit}
{% endhighlight %}

## HP-UX

HP-UX has since been EOL'd for MySQL, however this information might still
prove useful.  The HP-UX installation media contains per-directory packages,
with the contents representing how they are laid out on the destination file
system with each file gzip compressed.

{% highlight bash %}
#!/bin/sh
cd /path/to/extracted/hpux-dvd1
for pkg in $LIST_OF_PKGS
do
  for subpkg in ${pkg}/*
  do
    if [ ! -d "${subpkg}" ]; then
      continue
    fi
    for d in $(find ${subpkg} -type d)
    do
      mkdir -p ${CHROOTDIR}/$(echo ${d} \
        | sed -e "s#${subpkg}/##g" \
              -e "s#usr/newconfig/##g")
    done
    for f in $(find ${subpkg} -type f)
    do
      gzip -dc ${f} >${CHROOTDIR}/$(echo ${f} \
        | sed -e "s#${subpkg}/##g" \
              -e "s#usr/newconfig/##g")
    done
  done
done
{% endhighlight %}

Once this is done you'll need to fix up permissions in bin and lib directories
(make files executable), as well as create a bunch of symlinks for e.g. `/bin`
and `/lib`.

## OSX

For OSX we don't actually use a chroot tarball but instead create a sparse disk
image.  Currently the size of the &ldquo;chroot&rdquo; is very large as there's
no easy way to strip down an OSX install, so mounting a disk image is faster
than unpacking a chroot, plus it preserves various HFS-specific attributes.

You will likely need at least the BSD, BaseSystem, and Essentials packages.

{% highlight bash %}
# Create a sparse image to hold the chroot (which isn't really a directory)
hdiutil create -fs HFS+ -size 8g -type SPARSE -volname osx-chroot ${CHROOTDIR}
hdiutil attach -mountpoint ${CHROOTDIR} ${CHROOTDIR}.sparseimage
# Either attach a DVD image or the real thing
hdiutil attach -mountpoint /Volumes/osx-install /path/to/dvd
# Install packages
for pkg in BSD BaseSystem Essentials
do
  installer -verbose \
   -pkg /Volumes/osx-install/System/Installation/Packages/${pkg}.pkg \
   -target ${CHROOTDIR}
done
# Unmount
hdiutil detach ${CHROOTDIR}
hdiutil detach /Volumes/osx-install
{% endhighlight %}

## Red Hat / Oracle Linux / SuSE

For RPM-based distributions we use rpm to directly install packages into the
chroot.  The list of RPMs we install varies quite a lot from release to release,
usually by having to increase the number:

* RH3: 81
* RH4: 85
* RH5: 114
* RH6: 203

for the same functionality.

{% highlight bash %}
# Kludge for 'setup' RPM to install
mkdir -p ${CHROOTDIR}/var/lock/rpm
# If installing from an ISO:
mount -o loop /path/to/iso /mnt
# Path varies from release to release
cd /mnt/path/to/RPMs
rpm --root=${CHROOTDIR} -Uvh ${LIST_OF_RPMS}
{% endhighlight %}

## Solaris

Similar to RPM, we use the native package manager to install packages directly
into the chroot directory:

{% highlight bash %}
# Avoid prompts
sed -e "s/ask$/nocheck/" /var/sadm/install/admin/default > /tmp/admin-$$
pkgadd -a /tmp/admin-$$ -R ${CHROOTDIR} -d . ${LIST_OF_PKGS}
rm /tmp/admin-$$
{% endhighlight %}

## Windows

Ok, so of course we can't use chroot images for Windows, as it doesn't have
`chroot(2)`.  So here we use VirtualBox and its snapshot ability to load a clean
snapshot of a basic Windows install, do the tests, then shut down the virtual
machine, restore the snapshot, and boot up again.
