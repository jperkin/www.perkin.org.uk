---
layout: post
title: SmartOS development preview dataset
tags: [pkgsrc, smartos]
---

The datasets we produce for SmartOS are usually released on a quarterly
cadence, matching the upstream pkgsrc release branches.  This is often enough
to ensure that people can get up-to-date software with all the usual
improvements and bug fixes.

Occasionally though, users want the very latest and don't really want to wait
for 3 months to get it, and so to satisfy those users who crave the bleeding
edge I have produced a new dataset which is based upon pkgsrc trunk.

The package repository for this dataset will be constantly updated with the
very latest that pkgsrc has to offer, and so you will occasionally see breakage
as we integrate updates for core libraries and add new features.  Think of it
as being similar to Debian 'unstable', you get the very latest stuff but you
may need to do some maintenance every so often.

Here are some reasons why you may want to use this dataset:

* It is based upon the
  [multiarch](/posts/multiarch-package-support-in-smartos.html) code, so only
  one image is necessary.  No more needing to decide between the 32-bit or
  64-bit options.

* It is a full bulk build, so there are in the region of 9,000 packages to
  choose from (depending on the current state of pkgsrc trunk).

* It has all the Joyent specific changes integrated, so that means SMF support
  for many packages which we have written manifests for, static UID/GID
  allocation, various improvements, and uses the standard `/opt/local` prefix.

* There are some nice improvements only available in pkgsrc trunk, for example
  OpenSSL 1.0.1e with proper AES-NI support, and libpcap fixes from
  [@postwait](http://twitter.com/postwait) with a slew of networking utilities
  now available and working (these will be documented in a future post).

## How to install

Here is a quick start guide to getting the preview dataset up and running:

{% highlight console %}
: Fetch the dataset image and manifest files.  The image is 82MB.
$ mkdir -p /usbkey/images
$ cd /usbkey/images
$ curl -O http://pkgsrc.smartos.org/datasets/trunk-0.99.0.dsmanifest
$ curl -O http://pkgsrc.smartos.org/datasets/trunk-0.99.0.zfs.bz2

: Import it
$ imgadm install -m trunk-0.99.0.dsmanifest -f trunk-0.99.0.zfs.bz2

: Create a new zone using the dataset (change your json to suit).
$ vmadm create <<EOF
{
  "brand": "joyent",
  "image_uuid": "c91b3752-79c5-11e2-ad33-67667b9ee2c2",
  "max_physical_memory": 256,
  "alias": "trunk-0.99.0",
  "nics": [
    {
      "nic_tag": "admin",
      "ip": "dhcp"
    }
  ]
}
EOF
{% endhighlight %}

then login and start using it as you would with any other dataset.

## Known issues

With this being a bleeding-edge distribution, there will undoubtedly be
problems.The main one I am currently aware of is dependencies upon the GCC
runtime from the `/opt/pbulk` prefix used to build the packages, which looks
like this:

{% highlight console %}
# pkgin in samba
calculating dependencies... done.
/opt/pbulk/gcc47/lib/./libgcc_s.so.1, needed by samba-3.6.12nb1 is not present in this system.
/opt/pbulk/gcc47/lib/./libgcc_s.so.1, needed by tdb-1.2.11 is not present in this system.
[...]
{% endhighlight %}

We are actively working on fixing these dependencies, but in the meantime if
you require a package which is broken in this way you can work around it by
installing the `/opt/pbulk` bootstrap like this:

{% highlight console %}
# curl http://pkgsrc.smartos.org/packages/SmartOS/bootstrap/bootstrap-pbulk.tar.gz \
    | gtar -zxf - -C /
# /opt/pbulk/bin/pkgin -y install gcc47
{% endhighlight %}

The other issue to note is that not all packages have been converted to
multiarch.  Again we are actively working on this, but it will take some time
to go through all of the 12,000 or so packages in pkgsrc.

If you find any other problems, please feel free to raise them against our
GitHub project [here](https://github.com/joyent/pkgsrc/issues).  Or, even
better, follow my guides on
[building](/posts/pkgsrc-on-smartos-zone-creation-and-basic-builds.html)
[pkgsrc](/posts/pkgsrc-on-smartos-fixing-broken-builds.html) (you will want the
`joyent/release/trunk` branch) and have a go at fixing things yourself, we very
much welcome patches and pull requests!
