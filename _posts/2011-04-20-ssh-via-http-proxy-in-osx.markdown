---
layout: post
title: SSH via HTTP proxy in OSX
tags: [netcat, osx, ssh]
---

If you happen to be stuck behind a corporate firewall with only HTTP proxies
for external access, you might still be able to SSH out through them using the
built-in `nc` on OSX.

First, hope that the proxies haven't disabled the `CONNECT` method, then simply
add a section to your `.ssh/config` like this:

{% highlight text %}
Host foobar.example.com
    ProxyCommand          nc -X connect -x proxyhost:proxyport %h %p
    ServerAliveInterval   10
{% endhighlight %}

This will tunnel the connection through the HTTP proxy to the remote server.
The `ServerAliveInterval` setting is required as most proxies will drop the
connection after a period of inactivity.

To avoid issues with trying to connect to the host when not behind the
corporate firewall, replace the above with a fake entry for the proxy method
like this:

{% highlight text %}
Host foobar-proxy.example.com
    HostName              foobar.example.com
    ProxyCommand          nc -X connect -x proxyhost:proxyport %h %p
    ServerAliveInterval   10
{% endhighlight %}

Then use

{% highlight console %}
$ ssh foobar-proxy.example.com
{% endhighlight %}

when inside the firewall, and

{% highlight console %}
$ ssh foobar.example.com
{% endhighlight %}

when outside.

Simples, no external software required.
