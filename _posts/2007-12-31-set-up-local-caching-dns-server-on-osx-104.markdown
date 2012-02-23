---
layout: post
title: Set Up Local Caching DNS Server On OSX 10.4
tags: [dns, osx]
---

OSX 10.4 ships with ISC `named`, but is not configured correctly out of the
box.  Follow the instructions below to run a local caching name server.

First, we need to generate an rndc key.  The default `named.conf` comes configured to use one, but if it does not exist will bail with an error.  Simply run `rndc-confgen(1)` to create one.

{% highlight console %}
$ sudo rndc-confgen -a
{% endhighlight %}

Next, download the latest `named.root` file, as the supplied `named.ca` is
rather outdated (as you can see from the diff output).

{% highlight console %}
$ cd /var/named
$ sudo curl -O ftp://ftp.internic.net/domain/named.root
$ diff -u named.ca named.root
{% endhighlight %}

Now edit `/etc/named.conf`, we need to make three changes.  Firstly, the rndc
port is wrong in the default configuration, so make it:

{% highlight text %}
        inet 127.0.0.1 port 953 allow {any;}
{% endhighlight %}

Next, add a `listen-on` directive in the options section to instruct named to
only listen on certain interfaces, ensuring that we keep as secure as possible.
I have added the internal 192.168/16 LAN to my configuration so that Parallels
VMs and other machines can use the server, but if you do not need this then
just keep the localhost entry:

{% highlight text %}
        directory "/var/named";
        listen-on {
                127.0.0.1;
                192.168/16;
        };
{% endhighlight %}

Finally, change the root DNS server file from `named.ca` to `named.root` as
downloaded above.  You could simply overwrite the `named.ca` file instead with
`named.root`, however I like to keep defaults around as much as possible - you
never know if an update will blat your changes or not:

{% highlight text %}
zone "." IN {
        type hint;
        file "named.root";
};
{% endhighlight %}

All done.  All that's left to do is (re)start the service:

{% highlight console %}
$ sudo service org.isc.named stop
$ sudo service org.isc.named start
{% endhighlight %}

then run a quick test to ensure it is working correctly:

{% highlight console %}
$ dig www.perkin.org.uk @localhost
{% endhighlight %}

If you get a reply, configure your DNS server to be 127.0.0.1 and you're all
set.
