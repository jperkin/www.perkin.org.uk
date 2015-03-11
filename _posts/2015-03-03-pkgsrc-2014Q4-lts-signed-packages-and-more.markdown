---
layout: post
title: "pkgsrc-2014Q4: LTS, signed packages, and more"
tags: [pkgsrc, smartos]
---

The latest quarterly release of our [binary package
sets](http://pkgsrc.joyent.com/) for SmartOS and illumos introduces a number of
new features that I'm excited to announce.

## Long Term Support

We have produced quarterly releases of pkgsrc for a number of years, and since
the `pkgsrc-2013Q2` release have built every package available (10,000+), but
until now have not formalised our support for them.

This has meant that when serious security issues such as
[Heartbleed](http://en.wikipedia.org/wiki/Heartbleed) are disclosed, we are
obliged to backport these fixes to every branch we have ever produced.  Despite
all our efforts on [performance
improvements](/posts/building-packages-at-scale.html) this is still a large
effort and takes a long time on older branches where we do not have huge
resources available and backports can be tricker due to the differences
involved.

We've tried as best we can to keep these older branches updated, but as we've
added new branches each quarter the load increases further, and we cannot keep
doing this forever.

So, from `pkgsrc-2014Q4` (SmartOS 14.4.x images) we are introducing a new
yearly Long Term Support (LTS) model, which can be summarised as:

* Each `Q4` release (`pkgsrc-2014Q4`, `pkgsrc-2015Q4`, ...) will be an LTS
  release, and will receive suitable backports for 3 years from the time it is
  made available.

* We will continue to produce the other quarterly releases (SmartOS 15.1.x
  images and onwards), so that users can get the latest packages available, but
  each of those releases will be closed for updates as soon as the next one is
  available.

What is a "suitable" backport?  Anything which is a security or build fix, and
which does not affect API or ABI compatibility.  For example, we would not
introduce a new major version of OpenSSL or PHP into an LTS release, but we
would update OpenSSL from `1.0.1j` to `1.0.1k` or PHP from `5.4.37` to `5.4.38`
as they are minor releases which only introduce fixes.  We may also introduce
new leaf packages (i.e. those with no dependencies), for example new releases
of nodejs.

Who is the target market for each type of release?

* LTS is primarily useful for people who have a very static set of
  requirements, do not like changes, and are primarily interested in ensuring
  that the software they run does not have active vulnerabilities.

* Latest quarterly releases are for everyone else, users who want the latest
  stuff (and the latest security fixes), and are happy to reprovision their
  applications onto the newest images at regular intervals.

We hope the introduction of LTS releases satisfies both types of users, and
that by freeing up our resources spent on maintaining our legacy branches, we
can invest more time into ensuring the stability and security of the LTS
releases.

For SmartOS users, the LTS releases will receive an additional `-lts` suffix on
the image name to make it even easier to identify which are LTS.

## Image Name Changes

Related to LTS, we are also slightly changing our naming scheme for the base
images.  This is to accommodate the new `-lts` suffix, and also to allow us to
introduce a new "minimal" image, and make it clear which is which.

The current base image names are:

|             arch |        name |
|:----------------:|:-----------:|
| 32-bit           | `base`      |
| 64-bit           | `base64`    |
| 32-bit multiarch | `multiarch` |

With the introduction of the "minimal" image, the new names will be:

|             arch |        base name |        minimal name |
|:----------------:|:----------------:|:-------------------:|
| 32-bit           | `base-32`        | `minimal-32`        |
| 64-bit           | `base-64`        | `minimal-64`        |
| 32-bit multiarch | `base-multiarch` | `minimal-multiarch` |

And for LTS releases:

|             arch |            base name |            minimal name |
|:----------------:|:--------------------:|:-----------------------:|
| 32-bit           | `base-32-lts`        | `minimal-32-lts`        |
| 64-bit           | `base-64-lts`        | `minimal-64-lts`        |
| 32-bit multiarch | `base-multiarch-lts` | `minimal-multiarch-lts` |

What's the new "minimal" image?  It's effectively a stripped down "base", with
only the pkgsrc bootstrap and a couple of packages installed which are required
for the zone to boot correctly.  This will be of primary interest to users who
have custom requirements for their zones and/or produce their own images, and
want to ensure they are building on the smallest possible foundation.

As a quick comparison:

|                        image | packages installed | image size (compressed) |
|-----------------------------:|:------------------:|:-----------------------:|
| base-multiarch-lts 14.4.0    | 58                 | 161M                    |
| minimal-multiarch-lts 14.4.0 | 25                 | 31M                     |

The "minimal" images are fully functional and use the same package set, the
only difference is fewer packages are installed by default.

## Updated SmartOS Build Hosts

Up until now we have built all our package sets on an old
[SDC](https://github.com/joyent/sdc) 6.5 install, to ensure that the packages
we built can run across all hosts in the Joyent Public Cloud.  Building on the
lowest common denominator is great for compatibility, but has meant we are
running on a limited number of older machines, and each quarterly release added
yet more strain to already overloadeded systems.

Starting with 2014Q4 LTS we have moved to newer build hosts, running
`joyent_20141030T081701Z`.  This will soon be the most common platform
available in the Joyent cloud, and ensures we aren't tied to a legacy release
for another 3 years.  The next 3 quarterly releases (2015Q1-3) will also be
produced on this platform, and we will then evaluate which platform to choose
for the next LTS in 2015Q4.

This may mean incompatibilities if you are either running an older SmartOS
release, or if you are running a different illumos distribution which does not
have some of the newer SmartOS features.  You are most likely to see issues
where packages have picked up support for newer interfaces such as epoll or
inotify, which have been introduced as part of the LX brand work.

Please feel free to raise a [GitHub
issue](https://github.com/joyent/pkgsrc/issues) if this is causing problems for
you.  We are happy to turn off support for newer features if it improves
compatibility, as often these features are picked up by autoconf checks but
either aren't used correctly or should be using different interfaces on illumos
platforms anyway.

## Signed Packages

One of the primary concerns in recent times is provenance, and ensuring that
what you are receiving hasn't been tampered with in any way.  Until now our
packages have been protected by checksums, so that it is difficult for an
attacker to modify packages in-flight and deliver something we did not provide.

However, it isn't impossible, and to further ensure that what you are
installing came from Joyent we have implemented signed packages for 2014Q4
onwards.  Here's how it works:

* During the package build process, a detached package hash file is created
  which contains a SHA512 checksum of the package.
* This hash file is then signed with our PGP key.
* All three files are bundled into an `ar(1)` archive and delivered as the
  `package.tgz` file.
* At package install time, the archive is unpacked, the hash file is verified
  against our public PGP key, and then the package is checksummed against the
  recorded checksum in the hash file.  If all these checks pass, the package is
  installed, otherwise the installation is aborted.
 
Let's take a look at a package file (digest) to see in more detail:

{% highlight console %}
: We need to use GNU ar(1) from binutils as the Sun format is too limited.
$ gar xv /path/to/digest-20121220.tgz
x - +PKG_HASH
x - +PKG_GPG_SIGNATURE
x - digest-20121220.tgz
{% endhighlight %}

The `+PKG_HASH` file contains all the details about the actual digest package
which is stored in the archive.

{% highlight console %}
$ cat +PKG_HASH
pkgsrc signature

version: 1
pkgname: digest-20121220
algorithm: SHA512
block size: 65536
file size: 49083

b011cb5e9cdea303f3958a7338b37fd85252313da354ff86a82170974f384700634c5fbe9d5f7035f67ff8a4eecacc6cfbff43ba4d62b4e4743837d72612feef
end pkgsrc signature
{% endhighlight %}

We can verify that the checksum is correct.

{% highlight console %}
$ /usr/bin/digest -a sha512 digest-20121220.tgz
b011cb5e9cdea303f3958a7338b37fd85252313da354ff86a82170974f384700634c5fbe9d5f7035f67ff8a4eecacc6cfbff43ba4d62b4e4743837d72612feef
{% endhighlight %}

So we know that the `+PKG_HASH` file matches the `digest-20121220.tgz` package
file.  However, how do we know that both haven't been tampered with?  That's
where the `+PKG_GPG_SIGNATURE` file comes in.  It is a detached signature of
the `+PKG_HASH` file, signed with the Joyent key, so that if a malicious user
has tampered with the package file and generated a new checksum, the
`+PKG_HASH` file will no longer be verified and we know that it isn't what was
originally built.

We can verify that on the command line with GPG, as long as you have imported
the public key for that package set:

{% highlight console %}
$ gpg --verify +PKG_GPG_SIGNATURE +PKG_HASH
gpg: Signature made Sat Feb 21 02:10:43 2015 UTC using RSA key ID DE817B8E
gpg: Good signature from "Joyent Package Signing <pkgsrc@joyent.com>"
gpg: WARNING: This key is not certified with a trusted signature!
gpg:          There is no indication that the signature belongs to the owner.
Primary key fingerprint: 74C4 F303 BB45 7421 E42C  4DC4 FAE5 0048 FAA6 6EE0
     Subkey fingerprint: 2163 0D8B 4486 4587 9655  3748 76FA BBBB DE81 7B8E
{% endhighlight %}

A quick note about the warnings shown above.  This is where the PGP web of
trust comes in.  We know that the files were signed with the `DE817B8E` key,
but how do we know that the key belongs to `pkgsrc@joyent.com`?  It essentially
comes down to trust, and whether you believe this is really our key, or whether
someone has tricked you to believe that when it's not.  We can help persuade
you in a few ways:

* The bootstrap packages and our SmartOS images will come by default with that
  key installed in `/opt/local/etc/gnupg/pkgsrc.gpg`.  This is required so that
  you can start installing signed packages out of the box with no setup
  necessary.
* The public keys will be published to PGP key servers, and I will sign them
  with my key (`D532A578`).  My key in turn is signed by a number of other
  people, so that you can verify whether you believe I am who I say I am.
* We will publish the keys in a couple of other places, certainly on the main
  <http://pkgsrc.joyent.com/> site.

So, if you are a diligent user who checks all of these sources, an attacker
would need to infiltrate every single one of them simultaneously to have a
chance of delivering you a malicious packages which bypasses all of the checks.
Hopefully you are convinced that this would be extremely difficult.

Finally, how is all of this used in practise?  We've worked hard to make this
as transparent as possible, including integration of Alistair Crooks' excellent
[libnetpgpverify](http://netbsd.gw.com/cgi-bin/man-cgi?libnetpgpverify++NetBSD-current)
library into `pkg_install`, so as a user you should never be aware of any of it
unless there is a problem (a core Unix philosophy):

As mentioned above, the PGP key is distributed by default, so you don't need to
import keys or anything to get started.  We have added the following to
`/opt/local/etc/pkg_install.conf`:

{% highlight bash %}
GPG_KEYRING_VERIFY=/opt/local/etc/gnupg/pkgsrc.gpg
VERIFIED_INSTALLATION=trusted
{% endhighlight %}

`GPG_KEYRING_VERIFY` is set to our public key, and
`VERIFIED_INSTALLATION=trusted` means that a signature is required, and if one
isn't available then you are prompted for how to proceed.  Trying to install
the package file from our `ar(1)` archive example above shows what happens:

{% highlight console %}
$ pkg_add ./digest-20121220.tgz
No valid signature found for digest-20121220.
Do you want to proceed with the installation [y/n]?
n
Cancelling installation
pkg_add: 1 package addition failed
{% endhighlight %}

And if we try to install a package with an incorrect signature/hash:

{% highlight console %}
$ ed +PKG_HASH >/dev/null 2>&1 <<EOF
/^b011/s/b011/b010/
w
q
EOF
$ gar r test.tgz +PKG_HASH +PKG_GPG_SIGNATURE digest-20121220.tgz
gar: creating test.tgz
$ pkg_add ./test.tgz
pkg_add: unable to verify signature: Signature on data did not match
{% endhighlight %}

If you build your own packages then you're going to want to handle this
properly.  The simplest option is to use a custom `pkg_install.conf` when
installing your own packages, for example:

{% highlight console %}
$ echo "VERIFIED_INSTALLATION=never" >pkg_install_noverify.conf
$ pkg_add -C ./pkg_install_noverify.conf ./digest-20121220.tgz
{% endhighlight %}

The alternative is to sign your own packages.  This is reasonably
straight-forward:

* Enable `SIGN_PACKAGES` in `/opt/local/etc/mk.conf`:

{% highlight make %}
SIGN_PACKAGES=	gpg
{% endhighlight %}

* Install GPG, create a signing key, and then configure
  `/opt/local/etc/pkg_install.conf` with:

{% highlight bash %}
GPG=/path/to/gpg
GPG_SIGN_AS=your_pgp_key_id
{% endhighlight %}

With those additions, pkgsrc will prompt you for your PGP passphrase at package
time, and then sign the package with the key you have configured.  You can use
`gpg-agent` to automate this in a controlled environment.

## Bundled `pkg-vulnerabilities` Verification

Closely related to package signing, now that we have infrastructure support for
verification in our bootstrap packages, we've also enabled easy verification of
the `pkg-vulnerabilities` file.  For those who aren't aware, there is a team of
volunteers for pkgsrc who maintain a list of security vulnerabilities, which
can be checked against the list of installed packages and show you which ones
are currently vulnerable.

{% highlight console %}
: Fetch the latest pkg-vulnerabilities file.  SmartOS images have a crontab
: entry which does this nightly by default.
$ pkg_admin fetch-pkg-vulnerabilities

: The file is a compressed signed message containing a list of all known
: vulnerabilities.
$ gzip -dc /opt/local/pkg/pkg-vulnerabilities | nl -ba | sed -ne '1,4p' -e '27,28p'
     1  -----BEGIN PGP SIGNED MESSAGE-----
     2  Hash: SHA1
     3
     4  # $NetBSD: pkg-vulnerabilities,v 1.6187 2015/03/02 14:22:28 ryoon Exp $
    27  # package               type of exploit         URL
    28  cfengine<1.5.3nb3       remote-root-shell       ftp://ftp.NetBSD.org/pub/NetBSD/security/advisories/NetBSD-SA2000-013.txt.asc

: Show list of current known vulnerabilities
$ pkg_admin audit
Package gcc47-4.7.3nb6 has a denial-of-service vulnerability, see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=61601
Package gcc47-4.7.3nb6 has a memory-corruption vulnerability, see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=61582
Package mit-krb5-1.10.7nb4 has a denial-of-service vulnerability, see http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2014-5353
[...]
{% endhighlight %}

This provides you as the administrator with the information necessary to decide
whether the current vulnerabilities are acceptable in your environment.

However, there is a missing piece.  As you can see above, the vulnerabilities
file is signed.  This is important as an attacker with access to modify this
file could hide vulnerabilities from you and leave your system exposed.  With
the verification infrastructure now in place, we can now provide the
pkgsrc-security PGP key for you to easily verify that the `pkg-vulnerabilities`
file is as expected.

First we need to install the `pkgsrc-security@pkgsrc.org` PGP key on the
system.  As this key changes quite frequently, we cannot include it directly in
the bootstrap tarball as we have done with the package signing key, as it will
eventually be out of date.  So we instead provide a new `pkgsrc-gnupg-keys`
package which includes it, bundle that in the bootstrap, and we can then
distribute updates to this package as normal via `pkgin upgrade`.

{% highlight console %}
: The package contains a PGP keyring with the current pkgsrc-security key.
$ pkg_info -qL pkgsrc-gnupg-keys
/opt/local/share/gnupg/pkgsrc-security.gpg
{% endhighlight %}

We then add that file to our `/opt/local/etc/pkg_install.conf` file with:

{% highlight bash %}
GPG_KEYRING_PKGVULN=/opt/local/share/gnupg/pkgsrc-security.gpg
{% endhighlight %}

To verify the pkg-vulnerabilities file, use `pkg_admin` again:

{% highlight console %}
: Verify the basic checksum, looks good.
$ pkg_admin check-pkg-vulnerabilities /opt/local/pkg/pkg-vulnerabilities

: Verify the PGP signature, looks good.
$ pkg_admin check-pkg-vulnerabilities -s /opt/local/pkg/pkg-vulnerabilities

: Modify the file and try again, checks fail.
$ gzip -dc /opt/local/pkg/pkg-vulnerabilities \
  | grep -v 'mutt.*denial-of-service' \
  | gzip -9 >/var/tmp/pkg-vulnerabilities-test

$ pkg_admin check-pkg-vulnerabilities /var/tmp/pkg-vulnerabilities-test
pkg_admin: SHA1 hash doesn't match

$ pkg_admin check-pkg-vulnerabilities -s /var/tmp/pkg-vulnerabilities-test
pkg_admin: unable to verify signature: Signature on data did not match
{% endhighlight %}

Add these checks to your automated reports to ensure you aren't being lied to
about possible vulnerabilities.

## Reduced Package REQUIRES

Each package lists the libraries that it requires, and those are checked prior
to installation to ensure the package will work correctly on the target host.
Recently we've seen a few issues where some illumos distributions have moved
platform libraries to a different location (but still in the default search
path), which means the `REQUIRES` no longer match and the package won't
install.

From 2014Q4 we have reduced the way that `REQUIRES` are computed.  Previously
every library that was pulled in was recorded, essentially using the output of
`ldd`, so for example with the `iftop` package you end up with:

{% highlight console %}
$ pkg_info -Q REQUIRES iftop
/lib/libavl.so.1
/lib/libc.so.1
/lib/libcurses.so.1
/lib/libdevinfo.so.1
/lib/libdladm.so.1
/lib/libdlpi.so.1
/lib/libgen.so.1
/lib/libinetutil.so.1
/lib/libkstat.so.1
/lib/libm.so.2
/lib/libmd.so.1
/lib/libmp.so.2
/lib/libnsl.so.1
/lib/libnvpair.so.1
/lib/libpthread.so.1
/lib/librcm.so.1
/lib/libscf.so.1
/lib/libsec.so.1
/lib/libsocket.so.1
/lib/libumem.so.1
/lib/libuutil.so.1
/lib/libxml2.so.2
/lib/libz.so.1
/opt/local/gcc47/i386-sun-solaris2.11/lib/./libgcc_s.so.1
/opt/local/lib/libncurses.so.5
/opt/local/lib/libpcap.so.0
/usr/lib/libexacct.so.1
/usr/lib/libidmap.so.1
/usr/lib/libpool.so.1
/usr/lib/libsmbios.so.1
{% endhighlight %}

In 2014Q4 we have stopped using `ldd` to resolve the library dependencies, and
instead use `elfdump` to only look at the `NEEDED` entries that are recorded in
the `SHT_DYNAMIC` section for each executable.  This results in a much simpler
and direct list:

{% highlight console %}
$ pkg_info -Q REQUIRES iftop
/lib/libc.so.1
/lib/libm.so.2
/lib/libnsl.so.1
/lib/libsocket.so.1
/lib/libumem.so.1
/opt/local/lib/libncurses.so.5
/opt/local/lib/libpcap.so.0
{% endhighlight %}

and increases the portability of our packages across illumos distributions.

In case you are wondering where all the libraries have gone, they were
previously pulled in via `/opt/local/lib/libpcap.so.0` which has a dependency
on `/lib/libdlpi.so.1`, which in turn is the library responsible for pulling in
the large number of extra libraries from `/lib` and `/usr/lib`.

Now that we only mark `/lib/libdlpi.so.1` as our required dependency, the
distribution is free to manage its internal dependencies.  We also get a side
benefit of being able to easily identify packages which are incorrectly linking
against system versions of e.g. `libxml2.so.2` when they should instead be
using the pkgsrc version.

## Miscellaneous Improvements

There is the usual grab bag of updates in 2014Q4/14.4.x:

* `go-1.4.2` now includes Keith Wesolowski's patches to add support for cgo.
  This brings Go for illumos up to feature parity with other operating systems
  and increases the amount of Go software that will build and run.

* SmartOS 14.4.x images now deliver an SSL bundle in `/etc` which makes Go work
  correctly, and we also ensure that `/usr/bin/curl` has access to
  certificates.

* `libgo` has been removed from the `gcc47-libs` package.  It is unused, and
  doing this saves 40MB from the bootstrap kits and images.

* We now build with cwrappers, as detailed in my
  [performance](/posts/building-packages-at-scale.html) post.  This speeds up
  the builds a lot, so in the event of another Heartbleed we should be able to
  deliver updated packages a lot faster.

* `pkgin` is now at version 0.8.0 including support for the new
  `preferred.conf`, plus a number of important bug fixes.

* A number of small internal improvements to the build infrastructure.  As a
  user you shouldn't notice any changes, if you do please let us know!

Plus all the usual upstream pkgsrc changes as announced
[here](https://mail-index.netbsd.org/pkgsrc-users/2015/01/02/msg020854.html).

As always, please raise a [GitHub
issue](https://github.com/joyent/pkgsrc/issues) if you run into any problems or
have any suggestions on ways we can improve any of this stuff.

Enjoy!
