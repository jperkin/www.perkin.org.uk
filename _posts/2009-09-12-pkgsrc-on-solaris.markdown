---
layout: post
title: pkgsrc on Solaris
tags: [pkgsrc, solaris, zones]
---

For many years, building and installing third-party software on Solaris has
been a huge pain.  For people who do not use [pkgsrc](http://www.pkgsrc.org/),
that is.

Originating from the [NetBSD](http://www.netbsd.org/) project, pkgsrc is a
source-based cross-platform package manager.  If you've used FreeBSD ports,
then it is very similar as it derives from the same codebase, so the basic
premise is that you:

{% highlight console %}
$ cd /usr/pkgsrc/www/apache22
$ make package
{% endhighlight %}

and pkgsrc will download the source for Apache 2.2, compile it and all
dependancies, install it on the local system and create a package which can be
installed on other similar systems.

However, we've taken ports further and applied the NetBSD philosophy of
portability, meaning that it not only works on NetBSD, but across all \*BSD as
well as Linux, OSX, HP/UX, AIX, IRIX, QNX, Windows (via Interix), and of course
Solaris.

So while apt-get might be awesome, it only really works on Linux.  FreeBSD
might have way more ports than us, but only runs on FreeBSD and OSX.  pkgsrc
provides a consistent interface across all the platforms listed above, and in
some cases provides a superior package manager than the system provides.

Here's how I use pkgsrc on Solaris, in this specific case Solaris 10/x86.
Paths are specific to my setup, you can of course change them.

## Create a chroot/zone environment

I use the zones feature of Solaris 10 to ensure that all packages are built in
a sandbox.  This has a number of benefits:

* The running system is unaffected by the builds, in that they are not writing
  to the same file system.  This is good when you have misbehaving packages.
* You can separate the build and install phases, so that you can verify all the
  packages have been built and are correct before starting any install/upgrade
  procedure
* It's easier to catch package mistakes, e.g. unpackaged files.
* It avoids pollution from the host environment which may produce bad packages

For creating a zone, I wrote the following
[`create-zone`](http://{{ site.url }}/files/solaris-pkgsrc/create-zone)
script:

{% highlight bash %}
{% include solaris-pkgsrc/create-zone %}
{% endhighlight %}

And the corresponding
[`delete-zone`](http://{{ site.url }}/files/solaris-pkgsrc/delete-zone)
script is:

{% highlight bash %}
{% include solaris-pkgsrc/delete-zone %}
{% endhighlight %}

If you want to use them then there are some variables to set at the top, and
you may want to scan through them for additional bits to change, for example
[`create-zone`](http://{{ site.url }}/files/solaris-pkgsrc/create-zone)
copies my ssh public key which will most likely be wrong for your setup :-)

One additional piece of configuration for
[`create-zone`](http://{{ site.url }}/files/solaris-pkgsrc/create-zone) is
an optional SMF xml file.  I use this file to disable inetd inside the zone for
additional security, like so:

{% highlight xml %}
{% include solaris-pkgsrc/vm-generic.xml %}
{% endhighlight %}

The file should be named &lt;yourzonename&gt;.xml.  Mine is named
[`vm-generic.xml`](http://{{ site.url }}/files/solaris-pkgsrc/vm-generic.xml)
and I then create symlinks to it for each VM I want with that default
configuration.

## Fetch pkgsrc

pkgsrc is developed very rapidly.  Tracking nearly 9,000 pieces of third-party
software means there are always many updates.  Thankfully, we provide quarterly
branches for people who want more stability, and I recommend using the latest
quarterly release.  At time of writing, this is known as `pkgsrc-2009Q2`.
Within the next month or so we will release `pkgsrc-2009Q3`, and you can figure
out the names of future releases yourself.

The easiest way to get pkgsrc is using cvs.  I keep stuff like this under
`/content` as opposed to the default of `/usr`, you can use whatever you wish
but will need to change all my example scripts to match where you put it.

{% highlight console %}
$ cd /content
$ BRANCH="pkgsrc-2009Q2"
$ cvs -d anoncvs@anoncvs.netbsd.org:/cvsroot co -r${BRANCH} -d${BRANCH} -P pkgsrc
{% endhighlight %}

Alternatively, you can fetch either bzip2 or gzip archives of the current
branch.  I recommend the cvs method as, with the branch being updated for
security fixes and other important changes, you can easily track it using

{% highlight console %}
$ cd /content/pkgsrc-2009Q2
$ cvs update
{% endhighlight %}

## pkgsrc configuration

pkgsrc is configured using a `mk.conf` file,
[this](http://{{ site.url }}/files/solaris-pkgsrc/mk.conf) is mine:

{% highlight text %}
{% include solaris-pkgsrc/mk.conf %}
{% endhighlight %}

This is the primary configuration file for pkgsrc.  Again, you may need to
tailor this to your environment, and may find it useful to read the pkgsrc
guide to understand what it all means.

As I do a lot of pkgsrc development I have a number of virtual machines up and
running doing various bits and pieces.  Obviously I don't want to copy that
[mk.conf](http://{{ site.url }}/files/solaris-pkgsrc/mk.conf) around, so I
also have a small
[fragment](http://{{ site.url }}/files/solaris-pkgsrc/mk-include.conf) file
which is appended to each virtual machine's `mk.conf` (using the
`--mk-fragment` argument to `bootstrap`) and includes the global copy:

{% highlight text %}
{% include solaris-pkgsrc/mk-include.conf %}
{% endhighlight %}

The bulk build setup in pkgsrc requires its own configuration, and for this you
will need to edit a file inside pkgsrc.  There is an example file provided, so
what I usually do is symlink this to the real copy then I can easily keep it
up-to-date via cvs.

{% highlight console %}
$ cd /content/pkgsrc-2009Q2/mk/bulk
$ ln -s build.conf-example build.conf
$ vi build.conf
{% endhighlight %}

Again, you can find my personal build.conf here.

Finally, there is a configuration file for `pkg_chk` which is a package inside
pkgsrc which makes managing upgrades easier (ideally it should be a part of the
main pkgsrc tools but that's for another day).  `pkgchk.conf` is a list of
package directories, relative to the pkgsrc top level, which are to be built
and installed for this setup.  If you have a large installation then `pkg_chk`
has extra features to make it possible to share `pkgchk.conf` across a number of
machines and configure packages on a per-host, per-OS etc basis.

Thus, a sample
[`pkgchk.conf`](http://{{ site.url }}/files/solaris-pkgsrc/pkgchk.conf):
{% highlight bash %}
{% include solaris-pkgsrc/pkgchk.conf %}
{% endhighlight %}


It is highly likely you will want to change the `pkgchk.conf` file from what I
use :-)

## Build scripts

Once everything is set up, I have two scripts to build then update my packages,
intuitively called
[`build-packages`](http://{{ site.url }}/files/solaris-pkgsrc/build-packages):

{% highlight bash %}
{% include solaris-pkgsrc/build-packages %}
{% endhighlight %}

and
[`update-packages`](http://{{ site.url }}/files/solaris-pkgsrc/update-packages):

{% highlight bash %}
{% include solaris-pkgsrc/update-packages %}
{% endhighlight %}

These are pretty simple as all the hard work has all been done.
[`build-packages`](http://{{ site.url }}/files/solaris-pkgsrc/build-packages)
is ran inside the zone, then
[`update-packages`](http://{{ site.url }}/files/solaris-pkgsrc/update-packages)
on the main host.  These scripts hardcode the name of the branch currently
used, so you will need to update this when moving to newer releases.

## Quick recap

Ok, so here is the stuff I have for my setup and where I keep them:

<div class="posttable">
 <table>
  <thead>
   <tr><th style="width: 40%">Path</th><th>Description</th></tr>
  </thead>
  <tbody>
   <tr><td><code>/content/pkgsrc-2009Q2</code></td><td>Checked out pkgsrc tree, "2009Q2" branch</td></tr>
   <tr><td><code>/content/scripts/<a href="http://{{ site.url }}/files/solaris-pkgsrc/create-zone">create-zone</a></code></td><td>Creates Solaris zone</td></tr>
   <tr><td><code>/content/scripts/<a href="http://{{ site.url }}/files/solaris-pkgsrc/delete-zone">delete-zone</a></code></td><td>Uninstalls and deletes zone</td></tr>
   <tr><td><code>/content/scripts/<a href="http://{{ site.url }}/files/solaris-pkgsrc/build-packages">build-packages</a></code></td><td>Bulk build packages inside the zone</td></tr>
   <tr><td><code>/content/scripts/<a href="http://{{ site.url }}/files/solaris-pkgsrc/update-packages">update-packages</a></code></td><td>Updates installed packages</td></tr>
   <tr><td><code>/install/pkgsrc/misc/<a href="http://{{ site.url }}/files/solaris-pkgsrc/mk.conf">mk.conf</a></code></td><td>Main pkgsrc configuration file</td></tr>
   <tr><td><code>/install/pkgsrc/misc/<a href="http://{{ site.url }}/files/solaris-pkgsrc/mk-include.conf">mk-include.conf</a></code></td><td>Fragment file included in each zone's <code>mk.conf</code>, sources the global <code>mk.conf</code></td></tr>
   <tr><td><code>/install/pkgsrc/misc/<a href="http://{{ site.url }}/files/solaris-pkgsrc/pkgchk.conf">pkgchk.conf</a></code></td><td><code>pkg_chk</code> configuration file</td></tr>
   <tr><td><code>/install/zones/<a href="http://{{ site.url }}/files/solaris-pkgsrc/vm-generic.xml">vm-generic.xml</a></code></td><td>Shared SMF configuration file, symlinked to from e.g. "<code>vm0.xml</code>"</td></tr>
  </tbody>
 </table>
</div>

And these are the paths where stuff will be created:

<div class="posttable">
 <table>
  <thead>
   <tr><th>Path</th><th>Description</th></tr>
  </thead>
  <tbody>
   <tr><td><code>/install/pkgsrc/distfiles</code></td><td>Source tarballs of packages</td></tr>
   <tr><td><code>/install/pkgsrc/packages/2009Q2</code></td><td>Resulting binary packages</td></tr>
   <tr><td><code>/tmp/pkgsrc</code></td><td>Temporary build area for packages</td></tr>
   <tr><td><code>/content/vwww/www.adsl.perkin.org.uk/pkgstat</code></td><td>Bulk build results directory</td></tr>
  </tbody>
 </table>
</div>

It's definitely harder than it should be to get this all setup, but the good
news is that once it's done there's very little maintenance.

## Kicking it all off

Once everything is setup:

{% highlight console %}
$ /content/scripts/create-zone vm0
$ ssh vm0 /content/scripts/build-packages
$ /content/scripts/update-packages
$ /content/scripts/delete-zone vm0
{% endhighlight %}

This should do the lot.  Once
[`build-packages`](http://{{ site.url }}/files/solaris-pkgsrc/build-packages)
has finished you should, if you configured your email address in build.conf,
get an email with the bulk build results which looks similar to this:

<http://mail-index.netbsd.org/pkgsrc-bulk/2009/08/23/msg006883.html>

A fuller report is available if you configure a web server to serve the
`pkgstat` directory created by the bulk build, and this can help debug problems
(again see the above URL for an example).

You will need to add `/opt/pkg/sbin:/opt/pkg/bin` to `$PATH`.  Configuration
files are in `/etc/opt/pkg`, and log files and metadata are kept in
`/var/opt/pkg`.

## This stuff should be obsolete

While this all works well for me, it's pretty lame for users who just want to
install packages and have stuff work.  I'm working on providing regular updates
of binary packages, including a SVR4 package of the bootstrap kit, so that in
theory all a user needs to do is

{% highlight console %}
$ pkgadd TNFpkgsrc.pkg
$ pkg_add apache22
# Upgrade all installed packages to latest releases
$ pkg_chk -aurb
{% endhighlight %}

I'm almost there, just needs some tidying up and regular builds.  Please feel
free to help out!
