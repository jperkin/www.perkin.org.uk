---
layout: post
title: Last day at MySQL
tags: [mysql]
---

Today is my final day working on MySQL.  It has been an amazing 4.5 years, and
I've loved working on the technical challenges involved in producing a piece of
software which runs on so many different platforms, as well as working with so
many talented individuals.  I have learned a lot, which is just how I like it.

Times have changed since I first joined MySQL AB, of course.  But despite going
through two acquisitions, the day to day work hasn't changed much at all.  I
still get to work from home, which is something I am passionate about and feel
many companies are missing out on massively by still being stuck in an outdated
20th century mindset.  Oracle have continued to invest in MySQL, providing
additional headcount and extra hardware.  And the vast majority of people I
started working with back in 2007 are still with the company (don't believe the
FUD, folks) and working harder than ever.

I'm most proud of the work we have done internally to ensure our MySQL releases
are in excellent shape.  When I first joined, our internal 'PushBuild' system
was very limited, only able to handle a small number of pushes with reduced
testing across a few platforms, and the builds produced were completely
different to those that were released.

Nowadays, thanks to the investment made by Sun and Oracle, we have a large
server farm producing thousands of builds and hundreds of gigabytes of data
every day across all our supported platforms.  Those which are based on MySQL
5.5 or newer have additional package verification tests, using chroots and
virtual machines, to ensure that the RPM/MSI/etc packages can be installed,
run, and uninstalled, all automatically and on every push by developers.  We
run additional nightly and weekly tests which extend the default set of test
suites.  Our 5.5+ releases are produced directly in PushBuild.  And we are
looking to extend this to all MySQL products, not just the Server.

If the above sounds fun, keep an eye out for job posts, as the Release
Engineering team is looking to expand, and they are an amazing group of people
to work with.

I certainly found it fun, which is why I'm going to continue in that line of
work, and stay within Oracle, but move to the Linux group.  To be honest,
databases have never been a passion of mine, however I am rather fond of
Operating Systems, and so I am really looking forward to continuing to work on
continuous integration and testing, but with Oracle Linux and Oracle VM instead
of MySQL.  Plus, it will be nice to go back to a purely technical role – I have
learned over the last year or so that management isn't really my thing :)

To all my colleagues, past and present, thank you for the wonderful ride.  I
have many, many good memories, and hopefully we will keep in touch.
