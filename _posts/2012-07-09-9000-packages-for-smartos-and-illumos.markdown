---
layout: post
title: 9,000 packages for SmartOS and illumos
tags: [illumos, pkgin, pkgsrc, smartos]
---

At [Joyent](http://www.joyent.com/), we provide [SmartOS](http://smartos.org/)
users with a set of regularly updated binary packages which are tuned to work
well on our operating system.  The package manager we use, pkgsrc, does not yet
come with native support for e.g. SMF, and so we provide a limited set of
packages, ensuring that those we do we provide include such features.

However, often users will want packages which are not yet included in our build
set, and so to assist those users we have performed a full bulk build of the
unmodified pkgsrc-2012Q2 release, which resulted in well over 9,000 binary
packages to choose from.

In addition, thanks to binary compatibility, these packages can also be used on
your illumos distribution of choice (please let me know if this is not the
case!) if your native package manager does not provide the software you want.

Note that these packages do not come with SMF support, and may be different
from our official packages in terms of build options, etc.  Also, to avoid
conflict with our official packages, these have been built under a different
prefix:

{% highlight console %}
/opt/pkg	# main prefix
/etc/opt/pkg	# configuration files
/var/opt/pkg	# transient files
{% endhighlight %}

compared to our official packages:

{% highlight console %}
/opt/local	# main prefix
/opt/local/etc	# configuration files
/var		# transient files
{% endhighlight %}

To use them, run the following:

{% highlight console %}
# For SmartOS use the original build.
$ curl http://pkgsrc.smartos.org/packages/SmartOS/2012Q2/bootstrap.tar.gz \
    | gzip -dc | (cd /; sudo tar -xpf -)

# For other illumos, use the updated build which should work, but has fewer
# packages, and you will need to ignore warnings about x86_64 != i386.
$ curl http://pkgsrc.smartos.org/packages/SmartOS/2012Q2j1/bootstrap.tar.gz \
    | gzip -dc | (cd /; sudo tar -xpf -)

$ PATH=/opt/pkg/sbin:/opt/pkg/bin:$PATH
$ sudo pkgin -y update
$ pkgin avail | wc -l
    9401
$ pkgin search ...
$ sudo pkgin -y install ...
{% endhighlight %}

What's included?  Here are just a few highlights:

**Developer tools**

* PHP: 5.4.4, 5.3.14 + ~100 modules for each
* Perl: 5.14.2 + 1,780 modules
* Python: 3.2.3, 3.1.5, 2.7.3, 2.6.8, 2.5.6 + ~260 modules for 2.x
* Ruby: 1.9.3p194, 1.9.2pl320, 1.8.7.358 + ~450 modules for each
* Editors: (vim 7.2, emacs 23.4 and 24.1, xemacs 21.4)
* Revision control: (git 1.7.10.5, mercurial 2.2.2, bzr 2.5, svn 1.6.17)

**Web stack**

* Apache: 2.4.2, 2.2.22, 2.0.64, 1.3.42 + modules
* MySQL: 5.5.25, 5.1.63, 5.0.96
* PostgreSQL: 9.1.3, 9.0.7, 8.3.18
* Wordpress 3.4.1

**Desktop**

* GNOME 2.32.1 (not complete)
* KDE 4.8.4 (not complete)
* XFCE 4.6.1
* evilwm 1.1.0

plus thousands of miscellaneous utilities.

The long-term goal of course is to integrate all of our changes back into the
upstream pkgsrc repository and eventually provide a single package repository,
and we will continue to work on that endeavour.

Enjoy!
