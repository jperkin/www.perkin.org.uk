---
layout: post
title: SmartOS and the global zone
tags: [smartos]
---

One of the most common issues new users of SmartOS face is understanding the
role and design of the global zone.  Often they will download SmartOS and try
to start using it as they would any other Unix operating system, but quickly
run into basic problems such as installing packages or adding users.  However,
SmartOS is not your usual operating system, and it is imperative that you
understand two key principles:

* __SmartOS is specifically designed as an OS for running Virtual Machines__,
  not as a general purpose OS.

* __The global zone is effectively a read-only hypervisor__, and should only be
  used for creating and managing Virtual Machines.  Everything else should be
  performed inside Virtual Machines.

I should be clear at this point that *I am specifically addressing the issue of
downloading and running your own SmartOS installation*.  If you provision a
SmartMachine from Joyent, then you are running inside a Virtual Machine, and
this post does not apply - you are free to start serving up awesome
applications!

Let's look at a few aspects of the global zone which make it a great fit for
its intended purpose, and help explain why it doesn't work as you might expect.

## The global zone is a ramdisk

This is the key reason why things don't work as you might expect.  SmartOS does
not install to disk like other operating systems, instead it boots directly
from USB/CD/PXE into a mostly read-only environment.

Why is it done this way?  There are a number of good reasons:

* __Upgrades are trivial.__  No more patching, just reboot into a new image!
* __Increased disk space.__  No wasted space on disk to hold the OS, all the
  space is dedicated to VMs and user data.
* __Increased disk performance.__  It's common with other systems to have your
  OS installed to a pair of mirrored disks and then pool the remaining disks
  for data.  With SmartOS you can have all your disks in the same RAIDZ pool,
  increasing performance.
* __Additional security.__  Most of the system files are read-only, and `/etc`
  is re-created on each boot, making it much harder to exploit.
* __Increased stability.__  Ever had your root disks start to fail and system
  commands no longer run?  This doesn't happen on SmartOS.
* __Much simpler to install and provision__,  especially when you have a large
  number of machines.

So, what does this look like, and what are the implications?

{% highlight console %}
# zonename
global
# df -h / /usr
Filesystem             size   used  avail capacity  Mounted on
/devices/ramdisk:a     264M   219M    45M    83%    /
/devices/pseudo/lofi@0:1
                       376M   354M    22M    95%    /usr
# lofiadm
Block Device             File                           Options
/dev/lofi/1              /usr.lgz                       Compressed(gzip)
{% endhighlight %}

The root file system is a ramdisk, and `/usr` is a read-only loopback mount of
a single compressed file held on the ramdisk.

Apart from a few specific files and directories listed below, this means that
__you cannot change the global zone__.  To emphasise this point further:

* __You cannot add users.__
* __You cannot write anywhere under /usr.__
* __You cannot permanently store or change files under `/etc`, `/root`, ..__
* __Changes to SMF services will be reset each reboot.__

There are plenty of other things you cannot do, but hopefully this gives you
some idea of the restricted nature of the global zone environment.

If you are looking for a general purpose OS to serve as a NAS etc, then you can
do worse than give [OmniOS](http://omnios.omniti.com/) a spin - it has most of
the same features as SmartOS, but in a normal install-to-disk configuration.

Having said all that, let's look at some ways you can manage the global zone,
if you have settled on running SmartOS.

## So what __can__ I do?

Firstly, let's look at the key writeable areas:

{% highlight console %}
Filesystem             size   used  avail capacity  Mounted on
zones                  2.0T   143M   1.8T     1%    /zones
zones/var              2.0T   4.0G   1.8T     1%    /var
zones/opt              2.0T    55K   1.8T     1%    /opt
zones/usbkey           2.0T   154K   1.8T     1%    /usbkey
/usbkey/shadow         1.8T   154K   1.8T     1%    /etc/shadow
/usbkey/ssh            1.8T   154K   1.8T     1%    /etc/ssh
{% endhighlight %}

`zones` is the big zpool which is spread across all your disks, and SmartOS
will create a number of file systems on it for use in the global zone:

### /zones

This is where your Virtual Machines are stored, the datasets used to create
them, and some other key files related to zones.  Don't mess around in here
unless you know what you are doing.

### /var

We all like logs, so those are retained in `/var` as normal, as well as various
state files such as the current list of `imgadm` datasets and the SSH host keys.

### /opt

`/opt` is your main hook into more advanced setup of the global zone.  SmartOS
will import any SMF manifests it finds in `/opt/custom/smf`, which allows you
to implement `rc.local` functionality as demonstrated in [this
gist](https://gist.github.com/2606370).

As `/opt` is writeable you can also install packages as per [this wiki
page](http://wiki.smartos.org/display/DOC/Installing+pkgin), however you need
to bear in mind that, as explained earlier, things such as adding users are not
possible, so you may see various errors.

### /usbkey

When you first boot SmartOS and go through the rudimentary installer the
details you provide are stored in `/usbkey/config`, which is used during boot
to configure the machine.  If you need to change any of those variables, this
is the file you should edit.

There are also some variables which aren't set up by default, so if you want to

* Install an `authorized_keys` file for the root user.
* Set a keyboard map.

then have a read of [this post](/posts/smartos-global-zone-tweaks.html) I wrote
a while ago to find out how to configure those.

### /etc/shadow and /etc/ssh

In order to support some very basic configuration, a few `/etc` files are their
own mount points onto /usbkey so that changes to them are saved.

* `/etc/shadow` so that you can change the root password.
* `/etc/ssh` is initially where the SSH host keys were stored, however they are
  now stored under /var/ssh so don't be surprised if this mount point
  disappears at some point.

## Implementation

While we're on the subject, let's complete this post with a look at how the
global zone is implemented, for interested readers.

### GRUB

There is a [good wiki
guide](http://wiki.smartos.org/display/DOC/Remotely+Upgrading+A+USB+Key+Based+Deployment)
which describes how to mount the USB key.  Once you have done that you can take
a look at the GRUB configuration:

{% highlight console %}
: Assumes your current working directory is the USB key mountpoint.
# less boot/grub/menu.lst
...
title Live 64-bit (text)
   kernel /platform/i86pc/kernel/amd64/unix -B console=text,root_shadow='<crypt>',smartos=true
   module /platform/i86pc/amd64/boot_archive

title Live 64-bit (noinstall)
   kernel /platform/i86pc/kernel/amd64/unix -B console=text,root_shadow='<crypt>',standalone=true,noimport=true
   module /platform/i86pc/amd64/boot_archive
...
{% endhighlight %}

There are a few boot configuration variables which alter how the system is
started, and you can see how they are used by grepping for them in the SMF init
scripts under `/lib/svc`.

#### root\_shadow='crypt string'

This configures the default root password prior to /etc/shadow being mounted,
and changes for each release.  If you need to know what it is, then browse [the
download site](https://download.joyent.com/pub/iso/) and look at the
SINGLE\_USER\_ROOT\_PASSWORD.release.txt which correlates with your `uname -v`
output, or if you wish you could generate your own password and paste the new
crypted string in here.

Alternatively as a convenience you can find the default root password inside
the `platform` directory:

{% highlight console %}
# cat platform/root.password
seitee3oome4aiPh
{% endhighlight %}

#### smartos=true

This variable defines whether to perform the normal SmartOS global zone
initialisation, such as mounting `/usbkey` and configuring the system from the
`/usbkey/config` file (see `/lib/svc/method/fs-joyent` and
`/lib/svc/method/smartdc-config`.

If left unset (like in the 'Live 64-bit (noinstall)' boot option), these will
not be performed.  `standalone=true` should be set in those cases to avoid
trying to be a Joyent compute node.

#### noimport=true

Setting this will skip any configuration and mounting of zpools, and is useful
for if you have issues during the first installation and need to check disks,
etc.

It's likely that you do not need to change any of these variables, and if you
hit problems simply use the `noinstall` boot option and figure things out from
there.

### Platform image

The only other files on the USB key are:

{% highlight console %}
# find platform -type f
platform/i86pc/kernel/amd64/unix
platform/i86pc/amd64/boot_archive
platform/i86pc/amd64/boot_archive.gitstatus
platform/i86pc/amd64/boot_archive.manifest
{% endhighlight %}

These are mostly self-explanatory:

* `unix` is the SmartOS kernel.
* `boot_archive` is the ramdisk image containing the entire OS.
* `boot_archive.gitstatus` contains the tip revisions of the [github
  repositories](https://github.com/joyent/) used to build that particular
  image.
* `boot_archive.manifest` contains MD5 checksums of the OS files.

## Upgrades

Given we have just explained about the `platform` directory, it is also worth
pointing out that you do not have to reflash your USB key every time, which is
great if your server is inaccessible.  Instead, assuming your USB key is big
enough, you can simply download the newest
[platform-latest.tgz](https://download.joyent.com/pub/iso/platform-latest.tgz)
file, move the existing `platform` directory out of the way, and unpack
`platform-latest.tgz` there instead.  Doing this as an atomic operation is
preferred, for example:

{% highlight console %}
: As of writing this is 20121115T191935Z
# gtar zxf ~/platform-latest.tgz
# mv platform platform-$(uname -v) && mv platform-20121115T191935Z platform
{% endhighlight %}

This avoids having no `platform` directory, just in case you have a power cut
at that exact point in time!

## Summary

If you want to set up a file server or similar, then SmartOS is probably not
for you.  However, if you are interested in running Virtual Machines and are
able to do all of your work inside them, then SmartOS is perfect for that
purpose, and has a number of advantages over other operating systems.

Hopefully this has been useful, even if it is to deter you from using SmartOS!
