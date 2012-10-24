---
layout: post
title: Setting up Samba on SmartOS
tags: [pkgin, pkgsrc, samba, smartos]
---

A frequent question on #smartos IRC is how to set up SmartOS as a file server.
Due to the architecture of SmartOS and its focus on virtualisation, this isn't
as easy as on other systems, and some parts are simply not supported at this
time (e.g. NFS).

This guide, therefore, is a simple way to get Samba up and running so that you
can at least use a SmartOS machine as a file server, even if it's perhaps not
the protocol you would initially choose.

## Create new virtual machine

Let's start by creating a VM, here is what I use locally, you may want to tweak
the settings for your environment.  If you already have a suitable VM
configured you can just skip this step.

{% highlight bash %}
# Import the base1.8.1 image, though any base image will suffice.
$ imgadm update
$ imgadm import 55330ab4-066f-11e2-bd0f-434f2462fada

# I store all my VM configs in this directory
$ mkdir /usbkey/vmcfg

# vmadm configuration for 'store' VM
$ vi /usbkey/vmcfg/store.json
{% endhighlight %}
{% highlight json %}
{
  "brand": "joyent",
  "zfs_io_priority": 30,
  "image_uuid": "55330ab4-066f-11e2-bd0f-434f2462fada",
  "max_physical_memory": 256,
  "alias": "store",
  "hostname": "store",
  "resolvers": [
    "193.178.223.141",
    "208.72.84.24"
  ],
  "dns_domain": "adsl.perkin.org.uk",
  "nics": [
    {
      "nic_tag": "admin",
      "ip": "192.168.1.11",
      "netmask": "255.255.255.0",
      "gateway": "192.168.1.1"
    }
  ]
}
{% endhighlight %}
{% highlight bash %}
# Create the VM
$ vmadm create -f /usbkey/vmcfg/store.json
{% endhighlight %}

## Install Samba package

Next, log in to the VM and install the required packages.  These are not
currently available from the default repository, so we will use the generic
illumos package set:

{% highlight bash %}
$ zlogin <uuid>
{% endhighlight %}
{% highlight bash %}
# Download and unpack bootstrap kit
$ curl -s http://pkgsrc.smartos.org/packages/illumos/bootstrap/bootstrap-2012Q3-illumos.tar.gz \
    | gtar -zxf - -C /
$ PATH=/opt/pkg/sbin:/opt/pkg/bin:$PATH

# Install latest Samba package (others are available if necessary)
$ pkgin -y up
$ pkgin -y install samba-3.6
{% endhighlight %}

## Configure Samba

This part will differ based on your requirements, here is a simple working
example of a shared mount with full guest read/write access.

{% highlight bash %}
# Create shared mount user and mountpoint.
$ groupadd -g 500 store
$ useradd -u 500 -g 500 -c "Store user" -s /usr/bin/false -d /store store
$ mkdir /store
$ chown store:store /store
{% endhighlight %}

{% highlight bash %}
# Configure Samba
$ vi /etc/opt/pkg/samba/smb.conf
{% endhighlight %}

{% highlight ini %}
[global]
  security = share
  load printers = no
  guest account = store

; Comment out [homes] section

[store]
  path = /store
  public = yes
  only guest = yes
  writable = yes
  printable = no
{% endhighlight %}

## Startup scripts

Okay, so I'm lazy and whilst I should provide some SMF scripts and manifests
for this, it's simpler to just write an `rc.d` script! :-)

{% highlight bash %}
$ vi /etc/rc2.d/S99samba
{% endhighlight %}

{% highlight bash %}
#!/bin/sh

case "$1" in
start)
	# Start up Samba daemons
	/opt/pkg/sbin/nmbd -D
	/opt/pkg/sbin/smbd -D
	;;
stop)
	pkill -9 nmbd
	pkill -9 smbd
	;;
reload)
	pkill -HUP nmbd
	pkill -HUP smbd
	;;
esac
{% endhighlight %}

Finally, start it up!

{% highlight bash %}
$ chmod +x /etc/rc2.d/S99samba
$ /etc/rc2.d/S99samba start
{% endhighlight %}

## Multicast DNS

In order for shares to automatically show up in e.g. the OSX Finder, you will
need to be running some kind of mDNS service on the server.

The easiest solution is to simply enable `dns/multicast` in the global zone,
i.e.:

{% highlight bash %}
$ svcadm enable dns/multicast
{% endhighlight %}

This will then show up based on the hostname of the server, and clicking on it should show the `store` mount we created.

## All done

I hope this proves useful!
