---
layout: post
title: SmartOS is Not GNU/Linux
tags: [pkgsrc, smartos]
---

One of the requests we get from time to time is for SmartOS to look more like
GNU/Linux in layout and behaviour.  For example, config files in `/etc` instead
of `/opt/local/etc`, binaries under `/usr` instead of `/opt/local/{s,}bin`, GNU
userland by default, etc.

Whilst we believe in the technical merits of our current implementation and the
clean separation and upgrade possibilities it provides, we do recognise that
some users just don't care about those things and would prefer a system which
looks as close to the GNU/Linux environments they are used to.

Ordinarily this simply wouldn't be possible given that `/usr` is a read-only
mount from the [global zone](/posts/smartos-and-the-global-zone.html), however
with the highly flexible SmartOS
[Zones](http://wiki.smartos.org/display/DOC/Zones) architecture, coupled with
Joyent employing Zones guru [Jerry
Jelinek](http://wiki.smartos.org/display/DOC/Jerry+Jelinek), we are able to
provide you with an option to do exactly this.  As Jerry says, at Sun there was
even a native Linux brand, so pretty much anything is possible!

We call it 'SNGL' (pronounced 'snuggle'), which is an acronym for 'SmartOS is
Not GNU/Linux'.  Currently it is somewhat experimental, but we'd love for
people to try it out and provide feedback.

Here's how you can get it running.

## Install the latest platform

You need to be running SmartOS 20130222 or later.  Older platforms can be
coerced into working, you will just need to work around the lack of [this
commit](https://github.com/joyent/illumos-joyent/commit/c6920fb1d0f6cd852da06e049631f1ee274b5b9d)
by creating an empty `sngl_base.tar.gz` or so.

As usual, follow the instructions
[here](http://wiki.smartos.org/display/DOC/Remotely+Upgrading+A+USB+Key+Based+Deployment)
to upgrade an existing install.

## Get the SNGL dataset

{% highlight console %}
: Fetch the dataset image and manifest files.  The image is 107MB.
$ mkdir -p /usbkey/images
$ cd /usbkey/images
$ curl -O http://pkgsrc.smartos.org/datasets/sngl-0.99.0.dsmanifest
$ curl -O http://pkgsrc.smartos.org/datasets/sngl-0.99.0.zfs.bz2

: Import it
$ imgadm install -m sngl-0.99.0.dsmanifest -f sngl-0.99.0.zfs.bz2
{% endhighlight %}

## Create a new dataset

The important point to note here is that `brand` is set to `sngl`.

{% highlight console %}
: Create a new zone using the dataset (change your json to suit).
$ vmadm create <<EOF
{
  "brand": "sngl",
  "image_uuid": "4bf9530a-7ae5-11e2-bb4e-3bad5fbc3de9",
  "ram": 256,
  "quota": 10,
  "alias": "sngl-0.99.0",
  "nics": [
    {
      "nic_tag": "admin",
      "ip": "dhcp"
    }
  ]
}
EOF
{% endhighlight %}

At this point you should be able to log in and start using `pkgin` etc to
install new software (there are over 2,000 packages available) as normal, but
notice that:

* binaries are running from `/usr/bin`

* configuration files are in `/etc`

* the default userland tools are GNU variants (`ls`, `sed`, `awk`, `grep`, etc.)

For those that are interested, here is some further detail on how this is all
implemented.

## Brand configuration

The main setup is in `/usr/lib/brand/sngl`.  Firstly, `platform.xml` defines
the mount points to be used inside the zone, and here you can see how we are
able to use `/usr`:

{% highlight xml %}
        <global_mount special="/lib" directory="/system/lib"
            opt="ro,nodevices" type="lofs" />
        <global_mount special="/sbin" directory="/system/sbin"
            opt="ro,nodevices" type="lofs" />
        <global_mount special="/usr" directory="/system/usr"
            opt="ro,nodevices" type="lofs" />
{% endhighlight %}

We are transplanting the main system directories and mounting them under
`/system`.  This leaves `/usr` free for us to write packages to.

In order to support having the OS under `/system` there is some additional
configuration in `config.xml`.

{% highlight xml %}
        <initname>/system/sbin/init</initname>
        <login_cmd>/system/usr/bin/login -z %Z %u</login_cmd>
        <forcedlogin_cmd>/system/usr/bin/login -z %Z -f %u</forcedlogin_cmd>
        <user_cmd>/system/usr/bin/getent passwd %u</user_cmd>
{% endhighlight %}

This is where the flexibility of Zones really shines.  We are able to redefine
the path to init(1M) and others so that the zone can boot correctly.

In addition, we copy in the `crle` configuration files `ld.sys.config` and
`ld.sys64.config` so that binaries will look in `/system/usr/lib` for their
runtime libraries.

## Runtime and packages

The brand configuration is enough to set the zone up, but in order to make it
boot we need additional files available under `/usr`, there are simply too many
hardcoded paths.  For this we just symlink back to `/system/usr` from `/usr`
any files required.

Finally, we are able to perform a full pkgsrc bulk build with `LOCALBASE` set
to `/usr` within a chroot which emulates this layout, and when those packages
are installed they overwrite the compatability symlinks we have configured and
replace them with files from the packages.

Not all symlinks will be overwritten, though, which is why standard SmartOS
utilities such as `prstat(1M)` are still available, as the symlink for it still
exists.

## Reporting issues

As I mentioned, this is currently experimental, and there will be plenty of
problems.  However, at least from some initial testing, a reasonable amount of
things appear to work fine, and for users who want this particular layout it
may be good enough.

Please feel free to give it a try and report issues against [our GitHub
project](https://github.com/joyent/pkgsrc/issues).  Once we have it working
with a reasonable amount of stability we may be able to offer it as an option
in the [Joyent Public Cloud](http://www.joyent.com/).
