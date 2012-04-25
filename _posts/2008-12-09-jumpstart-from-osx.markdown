---
layout: post
title: Jumpstart from OSX
tags: [dhcp, grub, jumpstart, osx, solaris, tftp]
---

I recently built a new file server on which I planned to install Solaris 10
10/08.  I'm not a fan of CD/DVD installs, so wanted to jumpstart via PXE,
though I only had OSX handy.

Here's how I installed my new machine (gromit.adsl.perkin.org.uk/192.168.1.10)
from my iMac (192.168.1.30) over the local network.

_Note that since writing this piece I've updated to Solaris 10 10/09, and have
changed the examples to use that instead._

## Step 1, Prepare File System

First off, create a dedicated file system which we can export our jumpstart
configuration from. You can probably skip this and just use any existing file
system but this way everything is self-contained and we avoid NFS exporting
more than we need.

We use HFSX to ensure that the file system is case sensitive, HFS+ can cause
problems with `pkgadd(1M)`.

{% highlight console %}
$ hdiutil create -size 1g -type SPARSE -fs HFSX -volname "install" install
$ hdiutil attach install.sparseimage -mountpoint /install
{% endhighlight %}

Next up, download and mount `sol-10-u8-ga-x86-dvd.iso`.

{% highlight console %}
$ open sol-10-u8-ga-x86-dvd.iso
{% endhighlight %}

## Step 2, NFS

Share `/install` and the DVD via NFS with the correct options. `-alldirs`
allows clients to mount from any point within that file system (which jumpstart
requires), and `-maproot=root` is also required by jumpstart. As this allows
root-owned files to be created, make sure you understand the security risks.

{% highlight console %}
$ sudo vi /etc/exports
{% endhighlight %}
{% highlight text %}
/install                  -alldirs -maproot=root
/Volumes/SOL_10_1009_X86  -alldirs -maproot=root
{% endhighlight %}

{% highlight console %}
$ sudo nfsd checkexports && sudo nfsd enable
{% endhighlight %}

## Step 3, DHCP

For DHCP I happen to already use my Cisco router as a DHCP server on the local
network, so added the following configuration:

{% highlight text %}
ip dhcp pool gromit.adsl.perkin.org.uk
   host 192.168.1.10 255.255.255.0
   hardware-address xxxx.xxxx.xxxx
   bootfile /boot/grub/pxegrub
   next-server 192.168.1.30
   client-name gromit
   domain-name adsl.perkin.org.uk
   dns-server xxx.xxx.xxx.xxx
   default-router 192.168.1.1
{% endhighlight %}

however, given this is a guide for setting everything up under OSX I also tried
using ISC DHCP on OSX to prove it can be done that way too.

I used [pkgsrc](http://www.pkgsrc.org/) to install it (I'll add another blog
some time showing how to set up pkgsrc)

{% highlight console %}
$ cd /usr/pkgsrc/net/isc-dhcpd
$ sudo bmake package
{% endhighlight %}

And here is my DHCP configuration file in full:

{% highlight text %}
option domain-name "adsl.perkin.org.uk";
option domain-name-servers xxx.xxx.xxx.xxx;
ddns-update-style none;
authoritative;
log-facility local7;

subnet 192.168.1.0 netmask 255.255.255.0 {
    option routers 192.168.1.1;
}

group {
    filename "/boot/grub/pxegrub";
    next-server 192.168.1.30;

    host gromit {
        hardware ethernet xx:xx:xx:xx:xx:xx;
        fixed-address 192.168.1.10;
        option host-name "gromit.adsl.perkin.org.uk";
    }
}
{% endhighlight %}

Finally, start DHCP with:

{% highlight console %}
$ sudo /usr/pkg/sbin/dhcpd
{% endhighlight %}

Most parts of these configurations should be self-explanatory. The
`/boot/grub/pxegrub` entry is important for our next step, and I'd recommend
using that exact pathname for reasons explained later.

## Step 4, TFTP

Now, enable the TFTP server which comes with OSX. I added the `-s` option so
tftpd would chroot to the tftpboot directory, both for security reasons and
also to ensure that paths specified as `/path/to/file` would work correctly
(relative to `/install/tftpboot`).

I also changed the location of the tftpboot directory so that everything was
self-contained within the UFS image. In previous attempts I didn't do this and
ran into problems with GRUB which I think are again caused by case-insensitive
file systems.

{% highlight console %}
$ sudo vi /System/Library/LaunchDaemons/tftp.plist
{% endhighlight %}
{% highlight xml %}
[...]
    <key>ProgramArguments</key>
    <array>
        <string>/usr/libexec/tftpd</string>
        <string>-i</string>
        <string>-s</string>
        <string>/install/tftpboot</string>
    </array>
[...]
{% endhighlight %}

{% highlight console %}
$ mkdir /install/tftpboot
$ sudo launchctl load -w /System/Library/LaunchDaemons/tftp.plist
{% endhighlight %}

You can then create a test file and check that it's working as you expect, using:

{% highlight console %}
$ echo "testing" >/install/tftpboot/testfile
$ printf "verbose\ntrace\nget testfile\n" | tftp localhost
$ rm /install/tftpboot/testfile
{% endhighlight %}

## Step 5, GRUB

Next up, configure PXE booting using GRUB. We need to copy the GRUB images and
configuration from the Solaris install DVD then modify it for our environment:

{% highlight console %}
$ rsync -av /Volumes/SOL_10_1009_X86/boot/grub /install/tftpboot/boot/
$ rsync -av /Volumes/SOL_10_1009_X86/boot/multiboot /install/tftpboot/sol10u8x/
$ rsync -av /Volumes/SOL_10_1009_X86/boot/x86.miniroot /install/tftpboot/sol10u8x/
{% endhighlight %}

As we are copying the boot files from the DVD, they come hardcoded with
particular pathnames to e.g. the `menu.lst` file. While it may be possible to
pass extra parameters to pxegrub and load this from a different path, I simply
recommend doing as I do and replicating the `/boot/grub/` path structure so
that everything Just Works.

The `menu.lst` file includes kernel arguments and allows you to choose which
type of install to perform at startup. My file listed below has 3 choices:

* Unattended install using a graphical environment (if available). The
  &ldquo;install&rdquo; keyword after the kernel instructs it to perform an
  unattended install, so long as it can find the necessary settings from
  sysidcfg etc.
* As above, but force the use of the console and do not start a graphical
  environment (using the &ldquo;nowin&rdquo; keyword)
* A manual install, so you need to go through the steps of layout out disks,
  selecting packages, etc.

{% highlight console %}
$ vi /install/tftpboot/boot/grub/menu.lst
{% endhighlight %}
{% highlight text %}
default=0
timeout=60

title Solaris PXE Unattended Install
    kernel /sol10u8x/multiboot kernel/unix - install -B \
      install_media=192.168.1.30:/Volumes/SOL_10_1009_X86,\
      sysid_config=192.168.1.30:/install/jumpstart,\
      install_config=192.168.1.30:/install/jumpstart
    module /sol10u8x/x86.miniroot

title Solaris PXE Unattended Install (console)
    kernel /sol10u8x/multiboot kernel/unix - install nowin -B \
      install_media=192.168.1.30:/Volumes/SOL_10_1009_X86,\
      sysid_config=192.168.1.30:/install/jumpstart,\
      install_config=192.168.1.30:/install/jumpstart
    module /sol10u8x/x86.miniroot

title Solaris PXE Manual Install
    kernel /sol10u8x/multiboot kernel/unix -B \
      install_media=192.168.1.30:/Volumes/SOL_10_1009_X86
    module /sol10u8x/x86.miniroot
{% endhighlight %}

Anyone used to doing jumpstart but with RARP/bootparams will notice the
symmetry between `install_config` etc in the GRUB configuration and similar
options in `/etc/bootparams`. Make sure that the full kernel arguments are all
on one line, and that there are no spaces in between the
`install_media=..,sysid_config=..` options.

## Step 6, Jumpstart

Finally, set up your Jumpstart configuration. Here's what I personally use, you
may want something different:

{% highlight console %}
$ mkdir /install/jumpstart
$ cd /install/jumpstart
$ vi sysidcfg
{% endhighlight %}
{% highlight text %}
name_service=DNS
{
    domain_name=adsl.perkin.org.uk
    name_server=xxx.xxx.xxx.xxx
}
network_interface=PRIMARY
{
    default_route=192.168.1.1
    netmask=255.255.255.0
    protocol_ipv6=yes
}
nfs4_domain=dynamic
root_password=xxxxxxxx
terminal=xterm
timeserver=localhost
timezone=Europe/London
security_policy=NONE
service_profile=limited_net
system_locale=C
{% endhighlight %}

Ordinarily this file is processed using a `check` script available in the
`jumpstart_sample` directory on the Solaris DVD, however this only works from a
Solaris host. To create the `rules.ok` file, we need to strip out any comments
and put entries on one line, then create the checksum (although this isn't
actually necessary).

{% highlight console %}
$ vi rules # emacs sucks :)
{% endhighlight %}
{% highlight text %}
hostname gromit.adsl.perkin.org.uk - profile -
{% endhighlight %}

{% highlight console %}
$ cp rules rules.ok
$ echo "# version=2 checksum=$(cksum -o 2 rules | awk '{print $1}')" >> rules.ok
{% endhighlight %}

Machine profile. This gives me a full Solaris install (minus OEM stuff) on
mirrored ZFS disks with additional dump/swap space (the defaults made dump a
bit too small I found).

{% highlight console %}
$ vi profile
{% endhighlight %}
{% highlight text %}
install_type    initial_install
pool            store auto 4g 4g mirror c1t0d0s0 c1t1d0s0
bootenv         installbe bename sol10u8x
cluster         SUNWCall
{% endhighlight %}

## Step 7, Make A Cup Of Tea

With everything set up you should be able to enable PXE booting in your BIOS
and watch it automatically install. One small minor problem you may have if you
don't have a BIOS which allows you to hit F12 or similar and choose PXE booting
for one boot only is that it will infinitely cycle through installing,
rebooting, installing, rebooting.. until you change your boot options.

If this happens, I recommend making more cups of tea until you happen to return
in time to change the BIOS settings. If you aren't able to do this for a while,
you may need to add the extra steps 8, 9 and 10 titled &ldquo;Visit The
Bathroom&rdquo;.
