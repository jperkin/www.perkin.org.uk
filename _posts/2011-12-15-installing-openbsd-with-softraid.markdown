---
layout: post
title: Installing OpenBSD with softraid
tags: [openbsd, softraid]
---

This is more of a log for me than anything else, but perhaps someone will find
this useful.

OpenBSD includes a software RAID implementation which supports booting in newer
snapshots, and I was itching to install the latest version and use it as my
file server, which has 4 750GB disks.  There is a small bit of preparation work
to do prior to installing, which is the bulk of this entry, most of which is
based on [this undeadly.org
article](http://www.undeadly.org/cgi?action=article&sid=20111002154251).

Grab latest amd64
[snapshot](http://mirror.bytemark.co.uk/OpenBSD/snapshots/amd64/install50.iso),
boot it, drop into (S)hell mode and set up the disks:

{% highlight bash %}
#!/bin/sh

cd /dev
sh MAKEDEV sd1 sd2 sd3 sd4 sd5
for disk in 0 1 2 3
do
  # Clear beginning of disks..
  dd if=/dev/zero of=/dev/rsd${disk}c bs=1m count=10

  # ..and initialise new partition table
  fdisk -iy sd${disk}

  #
  # Create BSD disklabel:
  #
  # - 128m partitions at start to hold kernels for booting
  # - 4g spare raid on each disk for testing
  # - rest raid for main OS and data
  #   - OS and /home on first two mirrored disks
  #   - /store on second two mirrored disks
  #
  print "a a\n\n128m\n\na d\n\n4g\nraid\na e\n\n\nraid\nw\nq\n" \
    | disklabel -E sd${disk}

  # Clear beginning of raid partitions
  dd if=/dev/zero of=/dev/rsd${disk}d bs=1m count=10
  dd if=/dev/zero of=/dev/rsd${disk}e bs=1m count=10
done

# Create RAID1 mirrors
bioctl -c 1 -l sd0e,sd1e softraid0
bioctl -c 1 -l sd2e,sd3e softraid0

# Exit shell and start the (I)nstall
exit
{% endhighlight %}

As for the install, go with the sensible defaults, other than:

* change keyboard layout to 'uk'
* manually configure network, enable rtsol
* start ntpd
* do not expect to run X

When it comes to disk selection, choose sd4 as the root disk, and use the
following layout:

{% highlight text %}
# partition  size  mount
  sd4a       1G    /
  sd4b       8G    swap
  sd4d       1G    /tmp
  sd4e       8G    /var
  sd4f       16G   /usr
  sd4h       rest  /home
{% endhighlight %}

then initialise sd5 with:

{% highlight text %}
# partition  size  mount
  sd5a       2G    /altroot
  sd5d       8G    /scratch
  sd5e       rest  /store
{% endhighlight %}

Install the full OS, set the correct timezone, then before rebooting initialize
the boot partitions and copy the kernels to them.  Doing this on all of them
means we can boot from any disk.

{% highlight bash %}
#!/bin/sh

for disk in 0 1 2 3
do
  newfs sd${disk}a
  mount /dev/sd${disk}a /mnt2
  cp /mnt/bsd* /mnt2
  umount /mnt2
done
eject cd0a
reboot
{% endhighlight %}

Job done.
