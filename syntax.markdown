---
layout: post
title: Test syntax
tags: [these, are, just, made, up, tags, that, do, not, exist, do, not, duplicate]
date: 2012-04-19
---

This tests <strong>lots</strong> of *different* layout items.  Let's start with
[a link](http://www.netbsd.org/) I have clicked on, and [another
one](http://www.blahblahblahojnk234.neti/) which I haven't, and then continue
with a really long paragraph to test how readable prose is, because often I
find that my posts aren't very readable when you have lots of text in a
paragraph, quite like this one really, however it seems better if you keep
paragraphs shorter, but I don't really want to do that as it ends up looking
like BBC News with a paragraph per sentence which I just find a bit annoying
really.  Preferably I want this to read like a book, optimising for content and
all that.  I also want to ensure that `code which is embedded in a paragraph
has the correct font settings` and isn't a wildly different size to the rest of
the text.

_Note to add more stuff!_

Anyway, enough of that.  Here's an unordered list!

* One.  Two three four
* Five six seven with lots of extra text to make this wrap around so that we
  can test the layout of multiple lines.
* Eight.

And here is an ordered list!

1. One
2. Two
3. Four.  Not really!  Only joking
4. Four.  Really, this time.

Ok, <em>enough</em> of that.  Let's try some more stuff, but not without `a
whole lot of code in between` a bunch of text to see if the font size of
embedded code sections is ok.

# Big heading of the h1 variety.

I shouldn't really use these, as they are reserved for the title, but here's what one looks like.

## Main heading, h2, I should use these a lot

Does exactly what it says in the heading.

### A smaller h3, I may use these from time to time

But then again I may not!  I can be tricky like that.

#### A h4, like I'm ever going to use this!

I don't think I do, but maybe I'm wrong.  Now is probably a good time to add
another really long paragraph to check word wrapping and alignment and
justification and all that business, and to see if the headers stand out ok and
clearly break up the text.  Blah blah blah, I'm running out of things to write
now, so I'm just going to say some more blah blah blah and hope that nobody
will ever read this.  Why would anyone read this?  It's a boring syntax page on
my website which isn't linked from anywhere!  But, you never know, in this
crazy google-searching generation.

##### A h5, you don't see this every day

I don't think my css even handles these.

###### A h6

It definitely doesn't handle these.

## Tables

This is a table:

<div class="posttable">
 <table>
  <thead>
   <tr><th>Blah</th><th>Some more blah</th></tr>
  </thead>
  <tbody>
   <tr><td>Add some <code>code</code> and then add some more text.</td><td>This is blah blah blah</td></tr>
   <tr><td>One two three, hopefully this will overflow.  But how about if we overflow with <code>/a/really/long/pathname/which/probably/breaks/really/bad/operating/systems/anyway/but/we/do/not/care/as/we/just/want/to/test/word/wrapping/hey/how/about/that/</code></td><td>More blah</td></tr>
  </tbody>
 </table>
</div>

Ok, let's test some `code` examples:

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
