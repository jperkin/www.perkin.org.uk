---
layout: post
title: Serving multiple DNS search domains in IOS DHCP
tags: [cisco, dhcp, dns, ios, python]
---

I have a Cisco router at home which I also use as a DHCP server, and it works
pretty well.  Today I wanted to fix a long-standing issue on my network, in
that I want multiple DNS search domains.

First off, the domain-name DHCP option doesn't support multiple entries so we
can't use that.  So, off to try raw DHCP option codes.  You can find the list
of options
[here](http://www.iana.org/assignments/bootp-dhcp-parameters/bootp-dhcp-parameters.xml),
thus 119 is the one I want.

Trying a simple:

{% highlight text %}
ip dhcp pool host.net.example.com
   option 119 ascii net.example.com,example.com
{% endhighlight %}

didn't work at all.  A quick prod of lazyweb (in this case Simon on IRC)
suggested using hex input instead.  In order to do that we need to convert the
ASCII string into Cisco's hex sequence, which is as follows:

* Split domain name by dot
* Prepend each string by its length (in hex)
* NUL terminate each domain
* Dot-seperate the final string in 16bit chunks

To do this I wrote a quick Python script:

{% highlight python %}
#!/usr/bin/python

import sys

hexlist = []
for domain in sys.argv[1:]:
    for part in domain.split("."):
        hexlist.append("%02x" % len(part))
        for c in part:
            hexlist.append(c.encode("hex"))
    hexlist.append("00")

print "".join([(".%s" % (x) if i and not i % 2 else x) \
               for i, x in enumerate(hexlist)])
{% endhighlight %}

which can be used like this:

{% highlight console %}
$ ./cisco.py net.example.com example.com
036e.6574.0765.7861.6d70.6c65.0363.6f6d.0007.6578.616d.706c.6503.636f.6d00
{% endhighlight %}

Then back to IOS and paste it in:

{% highlight text %}
ip dhcp pool host.net.example.com
   option 119 hex 036e.6574.0765.7861.6d70.6c65.0363.6f6d.0007.6578.616d.706c.6503.636f.6d00
{% endhighlight %}

This seems to do what we want, though IOS appears to append a dot to each
domain when serving via DHCP.

One last note, if you use this in addition to domain-name then the option 119
list will be appended to the domain-name name in the search list, so you'd
actually want something like this:

{% highlight text %}
ip dhcp pool host.net.example.com
   domain-name net.example.com
   option 119 hex 0765.7861.6d70.6c65.0363.6f6d.00
{% endhighlight %}

to generate a resolv.conf containing:

{% highlight text %}
domain net.example.com
search net.example.com example.com.
{% endhighlight %}
