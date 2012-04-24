---
layout: post
title: Kickstart Oracle Linux in VirtualBox
tags: [kickstart, oracle-linux, virtualbox]
---

In my [previous post](http://{{ site.url }}/posts/kickstart-oracle-linux-from-ubuntu.html)
I configured an Ubuntu laptop as a Kickstart install server for a physical
machine I wanted to build.

Now that everything is configured for automated installs, it makes sense to use
the same infrastructure to install virtual machines too.  Everything can be
done from the command line, and new virtual machines can be provisioned very
quickly.

Again, I will use Oracle Linux 6.2 as an example.

## Create Virtual Machine

These commands create a new virtual machine, including disk, and configures it
for network booting.  If you don't already have VirtualBox installed:

{% highlight console %}
$ sudo apt-get install virtualbox
{% endhighlight %}

Set the name of the virtual machine as it appears in VirtualBox, this variable
is then used throughout:

{% highlight console %}
$ VM="Oracle Linux 6.2"
{% endhighlight %}

Create the VM:

{% highlight console %}
$ VBoxManage createvm --name "${VM}" --ostype "Oracle_64" --register
{% endhighlight %}

Create the hard disk (32GB expanding) and attach it via SATA. Note that I store
my VMs in `${HOME}/VirtualBox` rather than the default `${HOME}/VirtualBox VMs`.

{% highlight console %}
$ VBoxManage createhd --filename "VirtualBox/${VM}/${VM}.vdi" --size 32768

$ VBoxManage storagectl "${VM}" --name "SATA Controller" --add sata \
>   --controller IntelAHCI

$ VBoxManage storageattach "${VM}" --storagectl "SATA Controller" --port 0 \
>   --device 0 --type hdd --medium "VirtualBox/${VM}/${VM}.vdi"
{% endhighlight %}

Default RAM is 128MB, Oracle Linux installer requires at least 512MB however.
Once installed we can drop back down to 256MB or so:

{% highlight console %}
$ VBoxManage modifyvm "${VM}" --memory 512
{% endhighlight %}

Configure boot order. Put disk first, as on the first boot there is nothing on
it so it falls through to PXE for install, then after the install the disk is
bootable.

{% highlight console %}
$ VBoxManage modifyvm "${VM}" --boot1 disk --boot2 net --boot3 none --boot4 none
{% endhighlight %}

Change NIC type from the default e1000, as a vanilla VirtualBox install does
not include the firmware necessary to network boot from that device – it is
available in the "VirtualBox Extension Pack" add-on.  Switch to a plain PCNet
Fast III which does include PXE firmware.

{% highlight console %}
$ VBoxManage modifyvm "${VM}" --nictype1 Am79C973
{% endhighlight %}

VirtualBox does have the ability to serve TFTP directly from the file system by
placing files inside `${HOME}/.VirtualBox/TFTP/` but I prefer to just use the
network as it's already configured.

{% highlight console %}
$ VBoxManage modifyvm "${VM}" --nattftpserver1 10.0.2.2
$ VBoxManage modifyvm "${VM}" --nattftpfile1 pxelinux.0
{% endhighlight %}

## Configure pxelinux/kickstart

We just need a couple of tweaks to the configs from the last blog entry, as the
network addresses are different inside VirtualBox, and we also may want a
different kickstart configuration.

{% highlight console %}
$ sudo vi /var/lib/tftpboot/pxelinux.cfg/default
{% endhighlight %}

I just amended the existing entry to point to 10.0.2.2 which is the address of
the machine running VirtualBox, and a different ks-vm.cfg kickstart
configuration file, but you could also create a new label if you wanted to
regularly switch between different configurations:

{% highlight text %}
LABEL ol6.2
    KERNEL /ol6.2/vmlinuz
    APPEND initrd=/ol6.2/initrd.img ks=http://10.0.2.2/ks-vm.cfg
{% endhighlight %}

For virtual machines I use a slightly different configuration compared to
previously.  I've only shown the changes below, not the full file:

{% highlight console %}
$ sudo cp /usr/share/nginx/www/ks.cfg /usr/share/nginx/www/ks-vm.cfg
{% endhighlight %}

<br />

{% highlight text %}
# Update network configuration for DHCP instead of static
network --bootproto=dhcp
url --url=http://10.0.2.2/ol6.2

# Don't specify disks, just use default layout
bootloader --location=mbr --driveorder=sda
clearpart --all --initlabel

# Just add 'screen' to the default set of @base and @core packages.
%packages
screen
%end
{% endhighlight %}

## Start Virtual Machine

All that's left to do is to boot up the VM, and everything else should run automatically.

{% highlight console %}
$ VirtualBox --startvm "${VM}"
{% endhighlight %}

All done!
