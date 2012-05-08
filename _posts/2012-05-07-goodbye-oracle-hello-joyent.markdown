---
layout: post
title: Goodbye Oracle, Hello Joyent!
tags: [joyent, oracle, pkgsrc, smartos]
---

Back in 2001 when I started working for the BBC I was given a Sun Ultra 10
workstation running Solaris 8 and
[CDE](https://en.wikipedia.org/wiki/Common_Desktop_Environment) to do my job.
As a Linux/FreeBSD user at the time, and someone accustomed to things such as a
working vi implementation, recursive grep and Window Maker, this came as
something of a culture shock, and it wasn't long before I was compiling my own
software in a rapid attempt to build and configure a more usable desktop
environment - or at least one I was more comfortable in.

Building all that software by hand quickly became tedious, and so I was
delighted to find that [Christos
Zoulas](http://blog.netbsd.org/tnf/entry/interview_with_christos_zoulas) had
written a bunch of portability glue, known as Zoularis, which allowed pkgsrc
(similar to the FreeBSD ports system I was used to) to be used on Solaris.

It was still early days, however, and so over the next few years I and others
helped to improve Solaris support in pkgsrc.  By 2004 we had over
[1500](http://mail-index.netbsd.org/pkgsrc-bulk/2004/05/10/0001.html) packages
building on Solaris 9/SPARC using the Sun Studio compiler, and in 2010 there
were
[5000](http://{{site.url}}/posts/apt-get-and-5000-packages-for-solaris10x86.html)
packages for Solaris 10/x86, along with a native SFW package including pkgin
(an &ldquo;apt-get&rdquo; clone), making it easy to get up and running.

It was always something of a disappointment to me though that pkgsrc on Solaris
wasn't more widely deployed as I felt it provided major benefits over Blastwave
or IPS.  So it was great to see [Filip Hajný](http://twitter.com/mamash) of
[Joyent](http://www.joyent.com/) join the pkgsrc developers in 2009 for his
work on Solaris with Joyent using pkgsrc internally.

Since then they have:

* hired a [number](http://dtrace.org/blogs/bmc/2010/07/30/hello-joyent/)
  [of](http://dtrace.org/blogs/jerry/2010/09/23/joyent-wow/)
  [fantastic](http://dtrace.org/blogs/dap/2010/11/17/joining-joyent/)
  [engineers](http://dtrace.org/blogs/rm/2010/12/29/started-at-joyent/) from
  the ashes of Sun Microsystems, who have

* ported [KVM](http://www.linux-kvm.org/page/Main_Page) to their
  [SmartOS](http://smartos.org/) descendant of Solaris, making it a clear
  differentiator in the cloud computing arena (DTrace+ZFS+Zones+KVM is the
  perfect combination for multi-tenancy environments), as well as

* taken stewardship of [node.js](http://nodejs.org/) and again hired the
  [most](http://tinyclouds.org/) [prominent](http://izs.me/) engineers involved
  in that project

and thus over that time my desire to work there has only increased.

So, I am obviously delighted to say that today is my first day working for
Joyent, focusing on making pkgsrc work even better on SmartOS.

It isn't just the people and the technology which attracted me, though.  A
recent Twitter post by ex-Sun CEO and co-founder [Scott
McNealy](https://en.wikipedia.org/wiki/Scott_McNealy) says it well:

<div class="postimg">
  <img src="http://{{ site.url }}/files/images/scottm-tweet.png" alt="Joyent continue Sun spirit">
</div>

As a long time fan of Sun (I got over the initial shock of Solaris) who was
fortunate enough to work there, and as someone who experienced the fantastic
company culture of MySQL AB, it is this chance to again join an
engineering-driven company that &ldquo;kicks butt, has fun, doesn't cheat,
loves its customers, changes computing forever&rdquo; which excites me the
most.

Let's just hope Joyent don't turn out *exactly* the same as Sun Microsystems ;)
