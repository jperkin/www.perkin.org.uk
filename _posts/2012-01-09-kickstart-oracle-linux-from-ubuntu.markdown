---
layout: post
title: Kickstart Oracle Linux from Ubuntu
tags: [dhcp, kickstart, nginx, oracle-linux, tftp, ubuntu]
---

As my new job involves working on Oracle Linux, I figured I should migrate my
home server to it, which would also mean I could move it to a proper RAID10
configuration rather than relying on multiple RAID1′s.

My laptop runs Ubuntu, and I wanted to install the server from it using PXE and
Kickstart, so here's how I did it.

## Configure dhcpd

DHCP is required for two things, to give the server its network configuration,
and to point it at the pxe boot loader we want to use.

{% highlight console %}
$ sudo apt-get install isc-dhcp-server
$ sudo vi /etc/dhcp/dhcpd.conf
{% endhighlight %}

Here's the configuration I used, which says to configure 192.168.2.0/24 with a
dynamic DHCP range between 192.168.2.100 – 192.168.2.200, and to boot machines
using pxelinux.0 which is relative to the TFTP root directory (configured in
the next section):

{% highlight text %}
subnet 192.168.2.0 netmask 255.255.255.0 {
    range 192.168.2.100 192.168.2.200;
    filename "pxelinux.0";
}
{% endhighlight %}

The isc-dhcp-server install automatically tries to start the server, but will
fail as it isn't configured, so we restart it now that there is a working
configuration installed

{% highlight console %}
$ sudo /etc/init.d/isc-dhcp-server restart
{% endhighlight %}

## Configure tftpd

TFTP is a simple protocol used to transfer files over the network, and due to
its simplicity it is the primary way to network boot, as it can be easily
embedded into firmware.

All we need to do is install the TFTP daemon and syslinux which includes the
pxe boot loader, then put the pxelinux file into the tftproot area:

{% highlight console %}
$ sudo apt-get install syslinux tftpd-hpa
$ sudo cp /usr/lib/syslinux/pxelinux.0 /var/lib/tftpboot
{% endhighlight %}

## Configure Oracle Linux DVD

To save space on the laptop we can just mount the DVD read-only and install
from that:

{% highlight console %}
$ sudo mkdir /media/ol6.2
$ sudo mount -o loop,ro /path/to/OracleLinux-R6-U2-Server-x86_64-dvd.iso /media/ol6.2
{% endhighlight %}

However, we do need to copy the kernel and initrd image from the DVD into the
tftproot as they are required for booting:

{% highlight console %}
$ sudo mkdir /var/lib/tftpboot/ol6.2 /var/lib/tftpboot/pxelinux.cfg
$ sudo cp -a /mnt/images/pxeboot/{initrd.img,vmlinuz} /var/lib/tftpboot/ol6.2/
{% endhighlight %}

## Configure pxelinux

All that's left for the PXE stage is to configure the boot loader, and tell it
what kernel and initrd we want to use:

{% highlight console %}
$ sudo vi /var/lib/tftpboot/pxelinux.cfg/default
{% endhighlight %}

This configuration has just one entry which is booted after a short wait, but
pxelinux has many more options, including the ability to boot from local disk.

{% highlight text %}
DEFAULT	ol6.2
PROMPT 1
TIMEOUT 5

LABEL ol6.2
    KERNEL /ol6.2/vmlinuz
    APPEND initrd=/ol6.2/initrd.img ks=http://192.168.2.1/ks.cfg
{% endhighlight %}

Note the ks argument which specifies the kickstart file we will use, that and
the web server required to serve it will be set up next.

## Configure nginx

I chose nginx as it is small and simple to configure, but any web server will
do.

{% highlight console %}
$ sudo apt-get install nginx
$ sudo vi /etc/nginx/sites-available/default
{% endhighlight %}

The install will be performed over HTTP, so we need to make the DVD we mounted
earlier available.  This entry in the `server { }` section makes the DVD
available via http://192.168.2.1/ol6.2/:

{% highlight text %}
server {
[...]
    location /ol6.2 {
        root /media;
        autoindex on;
        allow all;
    }
{% endhighlight %}

Then start nginx (unlike isc-dhcp-server this isn't done automatically):

{% highlight text %}
$ sudo /etc/init.d/nginx start
{% endhighlight %}

## Configure kickstart

Finally, we create a kickstart configuration which specifies exactly how our
target machine is to be installed, and this allows a completely unattended
installation.

Ideally I should create a specific area for holding files like this, but as a
quick hack I simply put it into the default nginx web root (and thus available
as http://192.168.2.1/ks.cfg as configured earlier in the pxelinux.cfg/default
file:

{% highlight text %}
sudo vi /usr/share/nginx/www/ks.cfg
{% endhighlight %}

Here is my ks.cfg file in full. The only thing missing is a rootpw line to
automatically set a root password, however for maximum security I am happy to
forego a completely unattended installation and instead have the installer
prompt me to type it in during the install.

Some notes:

* UK keyboard language and timezone selected.
* Automatically reboot when the installer is finished.
* Point to the Oracle Linux DVD using the url directive.
* I have 4 disks configured with RAID1 for /boot, and RAID10 for swap and /.
* Disks are referred to by path, to ensure correct ordering.
* A small set of packages are installed, containing just the functionality I require.
* A small %post section is used to perform any fixes I want for the first boot.

{% highlight text %}
#
# Miscellaneous options.
#
install
keyboard uk
lang en_GB.UTF-8
reboot
selinux --enforcing
timezone Europe/London

#
# User setup.  I'd create my local user here and configure sudoers, but
# kickstart doesn't yet support creating a user with uid/gid of 1000 (the
# gid is always 500, even if you add the named group first).
#
authconfig --enableshadow --passalgo=sha512

#
# Networking.  The 'network' line needs to be on a single line
# for kickstart to work - it is only split here for the blog.
#
firewall --service=ssh
network --bootproto=static \
        --hostname=gromit.adsl.perkin.org.uk \
        --ip=192.168.2.10 \
        --netmask=255.255.255.0 \
        --gateway=192.168.2.1 \
        --nameserver=193.178.223.141,208.72.84.24 \
        --ipv6=auto
url --url=http://192.168.2.1/ol6.2

#
# Disk configuration.
#
bootloader --location=mbr --driveorder=sda,sdb,sdc,sdd
clearpart --all --initlabel
#
# /boot (RAID1 necessary as booting from RAID10 isn't supported)
#
part raid.00 --asprimary --size=1024 --ondisk=/dev/disk/by-path/pci-*-0*0
part raid.01 --asprimary --size=1024 --ondisk=/dev/disk/by-path/pci-*-1*0
part raid.02 --asprimary --size=1024 --ondisk=/dev/disk/by-path/pci-*-2*0
part raid.03 --asprimary --size=1024 --ondisk=/dev/disk/by-path/pci-*-3*0
raid /boot --level=1 --device=md0 --fstype=ext4 raid.00 raid.01 raid.02 raid.03
#
# swap, RAID10 of size RAM+2GB, give or take..
#
part raid.10 --asprimary --size=6144 --ondisk=/dev/disk/by-path/pci-*-0*0
part raid.11 --asprimary --size=6144 --ondisk=/dev/disk/by-path/pci-*-1*0
part raid.12 --asprimary --size=6144 --ondisk=/dev/disk/by-path/pci-*-2*0
part raid.13 --asprimary --size=6144 --ondisk=/dev/disk/by-path/pci-*-3*0
raid swap --level=10 --device=md1 --fstype=swap raid.10 raid.11 raid.12 raid.13
#
# /, RAID10 of remainder (have to specify an arbitrary --size even with --grow)
#
part raid.20 --asprimary --size=1024 --grow --ondisk=/dev/disk/by-path/pci-*-0*0
part raid.21 --asprimary --size=1024 --grow --ondisk=/dev/disk/by-path/pci-*-1*0
part raid.22 --asprimary --size=1024 --grow --ondisk=/dev/disk/by-path/pci-*-2*0
part raid.23 --asprimary --size=1024 --grow --ondisk=/dev/disk/by-path/pci-*-3*0
raid / --level=10 --device=md2 --fstype=ext4 raid.20 raid.21 raid.22 raid.23

#
# Packages.  @base and @core are pre-selected.
#
%packages
@cifs-file-server
@console-internet --optional
@development
@legacy-unix --optional
@mail-server
@network-server --optional
@network-tools
@nfs-file-server
@web-server
screen
%end

#
# Post-install fix-ups.
#
%post
#
# The 'network' directive doesn't support DNS search paths, so set those
# manually, and disable Network Manager.
#
printf "/^NM_CONTROLLED/s/yes/no/\nw\nq\n" \
  | ed /etc/sysconfig/network-scripts/ifcfg-eth0
printf "/^#/s/.*/search adsl.perkin.org.uk perkin.org.uk/\nw\nq\n" \
  | ed /etc/resolv.conf
#
# Disable unwanted services
#
chkconfig --del cups
%end
{% endhighlight %}

All done.
