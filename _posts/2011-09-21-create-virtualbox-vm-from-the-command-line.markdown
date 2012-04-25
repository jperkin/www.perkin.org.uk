---
layout: post
title: Create VirtualBox VM from the command line
tags: [virtualbox]
---

As something of a follow-up post to the previous entry, here's a quick recipe
for creating a Virtual Machine using the VirtualBox command line tools:

We're using Windows Server 2008 64bit as an example, modify to taste.

{% highlight console %}
$ VM='Windows-2008-64bit'
{% endhighlight %}

Create a 32GB &ldquo;dynamic&rdquo; disk.

{% highlight console %}
$ VBoxManage createhd --filename $VM.vdi --size 32768
{% endhighlight %}

You can get a list of the OS types VirtualBox recognises using:

{% highlight console %}
$ VBoxManage list ostypes
{% endhighlight %}

Then copy the most appropriate one into here.

{% highlight console %}
$ VBoxManage createvm --name $VM --ostype "Windows2008_64" --register
{% endhighlight %}

Add a SATA controller with the dynamic disk attached.

{% highlight console %}
$ VBoxManage storagectl $VM --name "SATA Controller" --add sata \
>  --controller IntelAHCI
$ VBoxManage storageattach $VM --storagectl "SATA Controller" --port 0 \
>  --device 0 --type hdd --medium $VM.vdi
{% endhighlight %}

Add an IDE controller with a DVD drive attached, and the install ISO inserted
into the drive:

{% highlight console %}
$ VBoxManage storagectl $VM --name "IDE Controller" --add ide
$ VBoxManage storageattach $VM --storagectl "IDE Controller" --port 0 \
>  --device 0 --type dvddrive --medium /path/to/windows_server_2008.iso
{% endhighlight %}

Misc system settings.

{% highlight console %}
$ VBoxManage modifyvm $VM --ioapic on
$ VBoxManage modifyvm $VM --boot1 dvd --boot2 disk --boot3 none --boot4 none
$ VBoxManage modifyvm $VM --memory 1024 --vram 128
$ VBoxManage modifyvm $VM --nic1 bridged --bridgeadapter1 e1000g0
{% endhighlight %}

Configuration is all done, boot it up! If you've done this one a remote
machine, you can RDP to the console via `vboxhost:3389`.

{% highlight console %}
$ VBoxHeadless -s $VM
{% endhighlight %}

Once you have configured the operating system, you can shutdown and eject the
DVD.

{% highlight console %}
$ VBoxManage storageattach $VM --storagectl "IDE Controller" --port 0 \
>  --device 0 --type dvddrive --medium none
{% endhighlight %}

Finally, it's a good idea to take regular snapshots so that you can always
revert back to a known-good state rather than having to completely re-install.

{% highlight console %}
$ VBoxManage snapshot $VM take <name of snapshot>
{% endhighlight %}

And, if you need to revert back to a particular snapshot:

{% highlight console %}
$ VBoxManage snapshot $VM restore <name of snapshot>
{% endhighlight %}

Enjoy!
