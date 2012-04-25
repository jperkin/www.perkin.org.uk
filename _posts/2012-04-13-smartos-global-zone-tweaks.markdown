---
layout: post
title: SmartOS global zone tweaks
tags: [smartos]
---

The basic premise behind [SmartOS](http://smartos.org/) is to provide a
netbooted global zone, and then do actual work inside kvm or zone based virtual
machines.  This has a number of advantages, not least that it's trivial to
upgrade to a newer release - you simply boot a newer image.

However, the read-only nature of the global zone means that if you want to make
changes to the global zone, then they need to be read from permanent storage,
rather than making changes as you would normally.

SmartOS creates a `/usbkey` file system on stable storage which holds
configuration for the global zone, and an init script
`/lib/svc/method/smartdc-config` which sources the file `/usbkey/config` for
configuration details.  By default this will mostly include details you
provided at install time, however there are additional values you can set to
customise the global zone further.

Here are a couple that I have found, and need for my personal use.

## Upload a root authorized_keys file

The `root` user's home directory is provided from the ramdisk, so any changes
you make will be wiped out on the next boot.  This is presumably so that newer
images can make changes to the shell rc files, for example to update `$PATH`
without worrying about all users having to merge these changes.

However, I'm not one for typing in passwords all day, so in order to store a
`/root/.ssh/authorized_keys` file you can do this:

{% highlight bash %}
mkdir -p /usbkey/config.inc
# paste your key into this file
vi /usbkey/config.inc/authorized_keys
echo "root_authorized_keys_file=authorized_keys" >>/usbkey/config
{% endhighlight %}

The `root_authorized_keys_file` variable points to a file in
`/usbkey/config.inc`, you can of course change the name if you wish.

## Set a keyboard map

By default a US keymap will be loaded for the console, if you want to use a
different one then find a suitable layout in `/usr/share/lib/keytables/type_6`
(in my case `uk`) and then:

{% highlight bash %}
echo "default_keymap=uk" >>/usbkey/config
{% endhighlight %}

## Look for more tweaks

As of time of writing (`joyent_20120405T204624Z`), these two appear to be the
only tweaks available which aren't already used by default, however this may
change in the future.  To see if there are any newer ones available, you can:

{% highlight bash %}
grep CONFIG_ /lib/svc/method/smartdc-config
{% endhighlight %}

and then have a deeper look into the script to see how they are used ;-)

## Run ad-hoc scripts

Note that while you may be tempted to think &ldquo;aha, it's just a shell
script, I can use it like `rc.local`&rdquo;, you can't - it's explicitly parsed
into variables, and trying to put commands in will just break the init script.

However, the `/lib/svc/method/manifest-import` script does import any SMF
manifests it finds in `/opt/custom/smf`, so if you want to run arbitrary
scripts, then have a look at
[@ryancnelson](https://twitter.com/#!/ryancnelson)'s
[example](http://www.psychicfriends.net/blog/archives/2012/03/21/smartosorg_run_things_at_boot.html)
and modify to suit your tastes.
