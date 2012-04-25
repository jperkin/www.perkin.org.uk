---
layout: post
title: Automated VirtualBox SmartOS installs
tags: [smartos, virtualbox]
---

This is a quick script I wrote to:
* Download the latest live ISO image of [SmartOS](http://smartos.org/)
* Create a VirtualBox VM, or update an existing VM with the latest ISO
* Configure the VM with a zones disk, and boot it!

For the first install you'll need to:
* Configure the network (likely just 'dhcp')
* Add `c0d0` as the zones disk
* Set a root password

After that it will just update the live ISO and use existing settings.  By
default it will create a port forward so that you can `ssh -p 8322
root@localhost` into the VM.

Here's the script in full (or you can download it
[here](http://{{ site.url }}/files/mksmartvm)):

{% highlight bash %}
{% include mksmartvm %}
{% endhighlight %}

Hopefully there will be a follow-up post which updates my [pkgsrc on
Solaris](http://{{ site.url }}/posts/pkgsrc-on-solaris.html) for SmartOS,
including zone setup etc.
