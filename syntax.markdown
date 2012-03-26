---
layout: post
title: Test syntax
---

Test syntax

## Python

This is some Python code:

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

## C

Some C!

{% highlight c %}
/*
 * Comment
 */

#define MACRO foo

int
main(int argc, char *argv[])
{
  int i;
  for (i = 0; i < 10; i++) {
    printf("Hello, world!\n");
  }
}
{% endhighlight %}

## Shell

This is some `/bin/sh` stuff...

{% highlight bash %}
#!/bin/sh
foo=bar
for i in $foo
do
  echo ${i}
  printf "hello, there!\n"
done
{% endhighlight %}

## XML

Ugh, xml.

{% highlight xml %}
<?xml version='1.0'?>
<!DOCTYPE service_bundle SYSTEM '/usr/share/lib/xml/dtd/service_bundle.dtd.1'>
<service_bundle type='profile' name='extract'>
  <service name='network/inetd' type='service' version='0'>
    <instance name='default' enabled='false'/>
  </service>
</service_bundle>
{% endhighlight %}
