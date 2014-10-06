---
layout: post
title: Building packages at scale
tags: [pkgsrc, smartos]
---

**tl;dr We are able to build 14,000 packages across 6 zones in 4.5 hours**

At Joyent we have long had a focus on high performance, whether it's through
innovations in [SmartOS](http://smartos.org), carefully selecting our
[hardware](http://eng.joyent.com/manufacturing/bom.html), or providing
customers with tools such as [DTrace](http://en.wikipedia.org/wiki/DTrace) to
identify bottlenecks in their application stacks.

When it comes to building packages for SmartOS it is no different.  We want to
build them as quickly as possible, using the fewest resources, but without
sacrificing quality or consistency.

To give you an idea of how many packages we build, here are the numbers:

| Branch |   Arch |  Success |  Fail |    Total |
|--------|-------:|---------:|------:|---------:|
| 2012Q4 |   i386 |    2,245 |    20 |    2,265 |
| 2012Q4 | x86_64 |    2,244 |    18 |    2,262 |
| 2013Q1 |   i386 |    2,303 |    40 |    2,343 |
| 2013Q1 | x86_64 |    2,302 |    39 |    2,341 |
| 2013Q2 |   i386 |   10,479 | 1,277 |   11,756 |
| 2013Q2 | x86_64 |   10,290 | 1,272 |   11,562 |
| 2013Q3 |   i386 |   11,286 | 1,317 |   12,603 |
| 2013Q3 | x86_64 |   11,203 | 1,308 |   12,511 |
| 2013Q4 |   i386 |   11,572 | 1,277 |   12,849 |
| 2013Q4 | x86_64 |   11,498 | 1,270 |   12,786 |
| 2014Q1 |   i386 |   12,450 | 1,171 |   13,621 |
| 2014Q1 | x86_64 |   12,356 | 1,150 |   13,506 |
| 2014Q2 |   i386 |   13,132 | 1,252 |   14,384 |
| 2014Q2 | x86_64 |   13,102 | 1,231 |   14,333 |
| Total  |        |          |       |  139,122 |

Now of course we don't continuously attempt to build 139,122 packages.
However, when something like
[Heartbleed](http://en.wikipedia.org/wiki/Heartbleed) happens, we backport the
fix to all of these branches, and a rebuild of something as heavily depended
upon as OpenSSL can cause around 100,000 packages to be rebuilt.

Each quarter we add another release branch to our builds, and as you can see
from the numbers above (2013Q1 and earlier were limited builds) the total
number of packages in pkgsrc grows with each release.

Recently I've been focussing on improving the bulk build performance, both to
ensure that fixes such as Heartbleed are delivered as quickly as possible, and
also to ensure we aren't wasteful in our resource usage as our package count
grows.  All of our builds happen in the Joyent public cloud, so any resources
we are using are taking away from the available pool to sell to customers.

Let's first take a walk through pkgsrc bulk build history, and then look at
some of the performance wins I've been working on.

## pkgsrc bulk builds, 2004

The oldest bulk build I performed that I can find is [this
one](http://mail-index.netbsd.org/pkgsrc-bulk/2004/05/11/msg000099.html).  My
memory is a little fuzzy on what hardware I was using at the time, but I
believe it was a SunFire v120 (1 x UltraSPARCIIi CPU @ 650MHz) with 2GB RAM.
This particular build was on Solaris 8.

As you can see from the results page, it took 13.5 days to build 1,810 (and
attempt but fail to build 1,128) packages!

Back then the build would have been single threaded with only one package being
built at a time.  There was no support for concurrent builds, `make -j`
wouldn't have helped much, and essentially you just needed to be very patient.

**May 2004: 2,938 packages in 13.5 days**

## pkgsrc bulk builds, 2010

[Fast forward 6
years](http://mail-index.netbsd.org/pkgsrc-bulk/2010/05/05/msg007404.html).  At
this point I'm building on much faster x86-based hardware (a Q9550 Core2Quad @
2.83GHz and 16G RAM) running Solaris 10, however the builds are still single
threaded and take 4 days to build 5,524 (and attempt but fail to build 1,325)
packages.

All of the speed increase is coming directly from faster hardware.

**May 2010: 6,849 packages in 4 days**

## pkgsrc @ Joyent, 2012 onwards

Shortly after [joining
Joyent](http://www.perkin.org.uk/posts/goodbye-oracle-hello-joyent.html), I
started setting up our bulk build infrastructure.  The first official build
from this was for [general illumos
use](http://www.perkin.org.uk/posts/9000-packages-for-smartos-and-illumos.html).
We were able to provide over 9,000 binary packages which took around [7 days to
build](http://mail-index.netbsd.org/pkgsrc-bulk/2012/07/09/msg008990.html).

At this point we're starting to see the introduction of very large packages
such as qt4, kde4, webkit, etc.  These packages take a significant amount of
time to build, so even though we are building on faster hardware than
previously, the combination of an increased package count as well as individual
package build times increasing mean we're not seeing a reduction in total build
time.

**July 2012: 10,554 packages in 7 days**

## Performance improvements

At this point we start to look at ways of speeding up the builds themselves.
As we have the ability to create build zones as required, the first step was to
introduce distributed builds.

### pbulk distributed builds

For pkgsrc in the 2007 Google Summer of Code [Jörg
Sonnenberger](http://www.sonnenberger.org/) wrote pbulk, a replacement for the
older bulk build infrastructure that had been serving us well since 2004 but
had started to show its age.  One of the primary benefits of pbulk was that it
supported a client/server setup to distribute builds, and so I worked on
building across 6 separate zones.  From my work log:

{% highlight text %}
2012-09-25 (Tuesday)

 - New pbulk setup managed a full bulk build (9,414 packages) in 54 hours,
   since then I've added another 2 clients which should get us well under 2
   days.
{% endhighlight %}

**September 2012: 10,634 packages in 2 days**

### Distributed chrooted builds

By far the biggest win so far was in June 2013, however I'm somewhat ashamed
that it took me so long to think of it.  By this time we were already using
chroots for builds, as it ensures a clean and consistent build environment,
keeps the host zone clean, and also allowed us to perform concurrent branch
builds (e.g. building i386 and x86_64 packages simultaneously on the same host
but in separate chroots).

What it took me 9 months to realise, however, was that we could simply use
multiple chroots for each branch build!  This snippet from my log is
enlightening:

{% highlight text %}
2013-06-06 (Thursday)

 - Apply "duh, why didn't I think of that earlier" patch to the pbulk cluster
   which will give us massively improved concurrency and much faster builds.

2013-06-07 (Friday)

 - Initial results from the re-configured pbulk cluster show it can chew
   through 10,000 packages in about 6 hours, producing 9,000 binary pkgs.
   Not bad.  Continue tweaking to avoid build stalls with large dependent
   packages (e.g. gcc/webkit/qt4).
{% endhighlight %}

Not bad indeed.  The comment is somewhat misleading, though, as this comment I
made on IRC on June 15th alludes to:

{% highlight text %}
22:27 < jperkin> jeez lang/mercury is a monster
22:28 < jperkin> I can build over 10,000 packages in 18 hours, but that
                 one package alone takes 7.5 hours before failing.
{% endhighlight %}

Multiple distributed chroots get us an awfully long way, but now we're stuck
with big packages which ruin our total build times, and no amount of additional
zones or chroots will help.

However, we are now under 24 hours for a full build for the first time.  This
is of massive benefit, as we can now do regular daily builds.

**June 2013: 11,372 packages in 18 hours**

### make -j vs number of chroots

An ongoing effort has been to optimise the `MAKE_JOBS` setting used for each
package build, balanced against the number of concurrent chroots.  There are a
number of factors to consider:

* The vast majority of `./configure` scripts are single threaded, so generally
  you should trade extra chroots for less `MAKE_JOBS`.
* The same goes for other phases of the package build (fetch, checksum,
  extract, patch, install, package).
* Packages which are highly depended upon (e.g. GCC, Perl, OpenSSL) should have
  a high `MAKE_JOBS` as even with a large number of chroots enabled, most of
  them will be idle waiting for those builds to complete.
* Larger packages are built towards the end of a bulk build run (e.g. KDE,
  Firefox) and these tend to be large builds.  Similar to above, as they are
  later in the build there will be fewer chroots active, so a higher MAKE_JOBS
  can be afforded.

Large packages like webkit will happily burn as many cores as you give them and
return you with faster build times, however giving them 24 dedicated cores
isn't cost-effective.  Our 6 build zones are sized at 16 cores / 16GB DRAM, and
so far the sweet spot seems to be:

* 8 chroots per build (bump to 16 if the build is performed whilst no other
  builds are happening).
* Default `MAKE_JOBS=2`.
* `MAKE_JOBS=4` for packages which don't have many dependents but are generally
  large builds which benefit from additional parallelism.
* `MAKE_JOBS=6` for webkit.
* `MAKE_JOBS=8` for highly-dependent packages which stall the build, and/or are
  built right at the end.

The `MAKE_JOBS` value is determined based on the current `PKGPATH` and is
dynamically generated so we can easily test new hypotheses.

With various tweaks in place, fixes to packages etc., we were running steady at
around 12 hrs for a full build.

**August 2014: 14,017 packages in 12 hours**

### cwrappers

There are a number of unique technologies in pkgsrc that have been incredibly
useful over the years.  Probably the most useful has been the wrappers in our
[buildlink](https://www.netbsd.org/docs/pkgsrc/buildlink.html) framework, which
allows compiler and linker commands to be analysed and modified before being
passed to the real tool.  For example:

{% highlight make %}
# Remove any hardcoded GNU ld arguments unsupported by the SunOS linker
.if ${OPSYS} == "SunOS"
BUILDLINK_TRANSFORM+=  rm:-Wl,--as-needed
.endif

# Stop using -fomit-frame-pointer and producing useless binaries!  Transform
# it to "-g" instead, just in case they forgot to add that too.
BUILDLINK_TRANSFORM+=  opt:-fomit-frame-pointer:-g
{% endhighlight %}

There are a number of other features of the wrapper framework, however it
doesn't come without cost.  The wrappers are written in shell, and fork a large
number of `sed` and other commands to perform replacements.  On platforms with
an expensive `fork()` implementation this can have quite a detrimental effect
on performance.

Jörg again was heavily involved in a fix for this, with his work on
[cwrappers](https://github.com/jsonn/pkgsrc/commit/35c0ef88572d984f4a8c8d287e82d537d13b0546)
for the 2007 Google Summer of Code, which replaced the shell scripts with C
implementations.  Despite being 99% complete, the final effort to get it over
the line and integrated into pkgsrc hadn't been finished, so in September 2014
I took on the task and the sample package results speak for themselves:

|   Package   | Legacy wrappers |   C wrappers  | Speedup |
|-------------|----------------:|--------------:|:-------:|
| wireshark   |  3,376 seconds  | 1,098 seconds |  3.07x  |
| webkit1-gtk | 11,684 seconds  | 4,622 seconds |  2.52x  |
| qt4-libs    | 11,866 seconds  | 5,134 seconds |  2.31x  |
| xulrunner24 | 10,574 seconds  | 5,058 seconds |  2.09x  |
| ghc6        |  2,026 seconds  | 1,328 seconds |  1.52x  |

As well as reducing the overall build time, the significant reduction in number
of forks meant the system time was a lot lower, allowing us to increase the
number of build chroots.  The end result was a reduction of over 50% in overall
build time!

The work is still ongoing to integrate this into pkgsrc, and we hope to have it
done for pkgsrc-2014Q4.

**September 2014: 14,011 packages in 5 hours 20 minutes**

## Miscellaneous fork improvements

Prior to working on cwrappers I was looking at other ways to reduce the number
of forks, using DTrace to monitor each internal pkgsrc phase.  For example the
`bmake wrapper` phase generates a shadow tree of symlinks, and in packages with
a large number of dependencies this was taking a long time.

Running DTrace to count totals of execnames showed:

{% highlight text %}
$ dtrace -n 'syscall::exece:return { @num[execname] = count(); }'
  [...]
  grep                                                             94
  sort                                                            164
  nbsed                                                           241
  mkdir                                                           399
  bash                                                            912
  cat                                                            3893
  ln                                                             7631
  rm                                                             7766
  dirname                                                        7769
{% endhighlight %}

Looking through the code showed a number of ways to reduce the large number of
forks happening here

### cat -> echo

`cat` was being used to generate a `sed` script, which sections such as:

{% highlight sh %}
cat <<EOF
s|^$1\(/[^$_sep]*\.la[$_sep]\)|$2\1|g
s|^$1\(/[^$_sep]*\.la\)$|$2\1|g
EOF
{% endhighlight %}

There's no need to fork here, we can just use the builtin `echo` command instead:

{% highlight sh %}
echo "s|^$1\(/[^$_sep]*\.la[$_sep]\)|$2\1|g"
echo "s|^$1\(/[^$_sep]*\.la\)$|$2\1|g"
{% endhighlight %}

### Use shell substitution where possible

The `dirname` commands were being operated on full paths to files, and in this
case we can simply use POSIX shell substitution instead, i.e.:

{% highlight sh %}
dir=`dirname $file`
{% endhighlight %}

becomes:

{% highlight sh %}
dir="${file%/*}"
{% endhighlight %}

Again, this saves a fork each time.  This substitution isn't always possible,
for example if you have trailing slashes, but in our case we were sure that
`$file` was correctly formed.

### Test before exec

The `rm` commands were being unconditionally executed in a loop:

{% highlight sh %}
for file; do
	rm -f $file
	..create file..
done
{% endhighlight %}

This is an expensive operation when you are running it on thousands of files
each time, so simply test for the file first and use a cheap (and builtin)
`stat(2)` call instead of forking an expensive `unlink(2)` for the majority of
cases.

{% highlight sh %}
for file; do
	if [ -e $file ]; then
		rm -f $file
	fi
	..create file..
done
{% endhighlight %}

At this point we had removed most of the forks, with DTrace confirming:

{% highlight text %}
$ dtrace -n 'syscall::exece:return { @num[execname] = count(); }'
  [...]
  [ full output snipped for brevity ]
  grep                                                             94
  cat                                                             106
  sort                                                            164
  nbsed                                                           241
  mkdir                                                           399
  bash                                                            912
  ln                                                             7631
{% endhighlight %}

The result was a big improvement, going from this:

{% highlight console %}
$ ptime bmake wrapper
  real     2:26.094442113
  user       32.463077360
  sys      1:48.647178135
{% endhighlight %}

to this:

{% highlight console %}
$ ptime bmake wrapper
  real       49.648642097
  user       14.952946135
  sys        33.989975053
{% endhighlight %}

Again note, not only are we reducing the overall runtime, but the system time
is significantly less, improving overall throughput and reducing contention on
the build zones.

### Batch up commands

The most recent changes I've been working on have been to further reduce forks
both by caching results and batching up commands where possible.  Taking the
previous example again, the `ln` commands are a result of a loop similar to:

{% highlight sh %}
while read src dst; do
	src=..modify src..
	dst=..modify dst..
	ln -s $src $dst
done
{% endhighlight %}

Initially I didn't see any way to optimise this, but upon reading the `ln`
manpage I observed the second form of the command which allows you to symlink
multiple files into a directory at once, for example:

{% highlight console %}
$ ln -s /one /two /three dir
$ ls -l dir
lrwxr-xr-x 1 jperkin staff 4 Oct  3 15:40 one -> /one
lrwxr-xr-x 1 jperkin staff 6 Oct  3 15:40 three -> /three
lrwxr-xr-x 1 jperkin staff 4 Oct  3 15:40 two -> /two
{% endhighlight %}

As it happens, this is ideally suited to our task as `$src` and `$dst` will for
the most part have the same basename.

Writing some `awk` allows us to batch up the commands and do something like
this:

{% highlight sh %}
while read src dst; do
	src=..modify src..
	dst=..modify dst..
	echo "$src:$dst"
done | awk -F: '
{% endhighlight %}
{% highlight awk %}
{
	src = srcfile = $1;
	dest = destfile = destdir = $2;
	sub(/.*\//, "", srcfile);
	sub(/.*\//, "", destfile);
	sub(/\/[^\/]*$/, "", destdir);
	# 
	# If the files have the same name, add them to the per-directory list
	# and use the 'ln file1 file2 file3 dir/' style, otherwise perform a
	# standard 'ln file1 dir/link1' operation.
	#
	if (srcfile == destfile) {
		if (destdir in links)
			links[destdir] = links[destdir] " " src
		else
			links[destdir] = src;
	} else {
		renames[dest] = src;
	}
	#
	# Keep a list of directories we've seen, so that we can batch them up
	# into a single 'mkdir -p' command.
	#
	if (!(destdir in seendirs)) {
		seendirs[destdir] = 1;
		if (dirs)
			dirs = dirs " " destdir;
		else
			dirs = destdir;
	}
}
END {
	#
	# Print output suitable for piping to sh.
	#
	if (dirs)
		print "mkdir -p " dirs;
	for (dir in links)
		print "ln -fs " links[dir] " " dir;
	for (dest in renames)
		print "ln -fs " renames[dest] " " dest;
}
{% endhighlight %}
{% highlight sh %}
' | sh
{% endhighlight %}

There's an additional optimisation here too - we keep track of all the
directories we need to create, and then batch them up into a single `mkdir -p`
command.

Whilst this adds a considerable amount of code to what was originally a simple
loop, the results are certainly worth it.  The time for `bmake wrapper` in
kde-workspace4 which has a large number of dependencies (and therefore symlinks
required) reduces from 2m11s to just 19 seconds.

**Batching wrapper creation: 7x speedup**

### Cache results

One of the biggest recent wins was in a piece of code which checks each ELF
binary's `DT_NEEDED` and `DT_RPATH` to ensure they are correct and that we have
recorded the correct dependencies.  Written in awk there were a couple of
locations where it forked a shell to run commands:

{% highlight awk %}
cmd = "pkg_info -Fe " file
if (cmd | getline pkg) {

...

if (!system("test -f " libfile))) {
{% endhighlight %}

These were in functions that were called repeatedly for each file we were
checking, and in a large package there may be lots of binaries and libraries
which need checking.  By caching the results like this:

{% highlight awk %}
if (file in pkgcache)
	pkg = pkgcache[file]
else
	cmd = "pkg_info -Fe " file
	if (cmd | getline pkg) {
		 pkgcache[file] = pkg

...

if (!(libfile in libcache))
	libcache[libfile] = system("test -f " libfile)
if (!libcache[libfile]) {
{% endhighlight %}

This simple change made a massive difference!  The kde-workspace4 package
includes a large number of files to be checked, and the results went from this:

{% highlight text %}
$ ptime bmake _check-shlibs
=> Checking for missing run-time search paths in kde-workspace4-4.11.5nb5

real     7:55.251878017
user     2:08.013799404
sys      5:14.145580838

$ dtrace -n 'syscall::exece:return { @num[execname] = count(); }'
dtrace: description 'syscall::exece:return ' matched 1 probe
  [...]
  greadelf                                                        298
  pkg_info                                                       5809
  ksh93                                                         95612
{% endhighlight %}

to this:

{% highlight text %}
$ ptime bmake _check-shlibs
=> Checking for missing run-time search paths in kde-workspace4-4.11.5nb5

real       18.503489661
user        6.115494568
sys        11.551809938

$ dtrace -n 'syscall::exece:return { @num[execname] = count(); }'
dtrace: description 'syscall::exece:return ' matched 1 probe
  [...]
  pkg_info                                                        114
  greadelf                                                        298
  ksh93                                                          3028
{% endhighlight %}

**Cache awk system() results: 25x speedup**

### Avoid unnecessary tests

The biggest win so far though was also the simplest.  One of the pkgsrc tests
checks all files in a newly-created package for any `#!` paths which point to
non-existent interpreters.  However, do we really need to test _all_ files?
Some packages have thousands of files, and in my opinion, there's no need to
check files which are not executable.

We went from this:

{% highlight sh %}
if [ -f $file ]; then
	..test $file..
{% endhighlight %}
{% highlight text %}
  real     1:36.154904091
  user       17.554778405
  sys      1:10.566866515
{% endhighlight %}

to this:

{% highlight sh %}
if [ -x $file ]; then
	..test $file..
{% endhighlight %}
{% highlight text %}
  real        2.658741177
  user        1.339411743
  sys         1.236949825
{% endhighlight %}

Again DTrace helped in identifying the hot path (30,000+ `sed` calls in this
case) and narrowing down where to concentrate efforts.

**Only test shebang in executable files: ~50x speedup**

## Miscellaneous system improvements

Finally, there have been some other general improvements I've implemented over
the past few months.

### bash -> dash

`dash` is renowned as being a leaner, faster shell than `bash`, and I've
certainly observed this when switching to it as the default `$SHELL` in builds.
The normal concern is that there may be non-POSIX shell constructs in use, e.g.
brace expansion, but I've observed relatively few of these, with the results
being (prior to some of the other performance changes going in):

| Shell | Successful packages | Average total build time |
|:-----:|:-------------------:|:------------------------:|
|  bash |              13,050 |                  5hr 25m |
|  dash |              13,020 |                  5hr 10m |

It's likely with a small bit of work fixing non-portable constructs we can
bring the package count for `dash` up to the same level.  Note that the
slightly reduced package count does not explain the reduced build time, as
those failed packages have enough time to complete successfully before other
larger builds we're waiting on are completed anyway.

### Fix libtool to use printf builtin

libtool has a build-time test to see which command it should call for advanced printing:

{% highlight sh %}
# Test print first, because it will be a builtin if present.
if test "X`( print -r -- -n ) 2>/dev/null`" = X-n && \
   test "X`print -r -- $ECHO 2>/dev/null`" = "X$ECHO"; then
  ECHO='print -r --'
elif test "X`printf %s $ECHO 2>/dev/null`" = "X$ECHO"; then
  ECHO='printf %s\n'
else
  # Use this function as a fallback that always works.
  func_fallback_echo ()
  {
    eval 'cat <<_LTECHO_EOF
$[]1
_LTECHO_EOF'
  }
  ECHO='func_fallback_echo'
fi
{% endhighlight %}

Unfortunately on SunOS, there is an actual `/usr/bin/print` command, thanks to
ksh93 polluting the namespace.  libtool finds it and so prefers it over printf,
which is a problem as there is no `print` in the POSIX spec, so neither dash
nor bash implement it as a builtin.

Again, this is unnecessary forking that we want to fix (libtool is called a
**lot** during a full bulk build!)  Thankfully pkgsrc makes this easy - we can
just create a broken `print` command which will be found before
`/usr/bin/print`:

{% highlight make %}
.PHONY: create-print-wrapper
post-wrapper: create-print-wrapper
create-print-wrapper:
	${PRINTF} '#!/bin/sh\nfalse\n' > ${WRAPPER_DIR}/bin/print
	${CHMOD} +x ${WRAPPER_DIR}/bin/print
{% endhighlight %}

saving us millions of needless execs.

### Parallelise where possible

There are a couple of areas where the pkgsrc bulk build was single threaded:

#### Initial package tools bootstrap

It was possible to speed up the bootstrap phase by adding custom `make -j`
support, reducing the time by a few minutes.  

#### Package checksum generation

Checksum generation was initially performed at the end of the build running
across all of the generated packages, so an obvious fix for this was to perform
individual package checksum generation in each build chroot after the package
build had finished and then simply gather up the results at the end.

#### `pkg_summary.gz` generation

Similarly for `pkg_summary.gz` we can generate individual per-package `pkg_info
-X` output and then collate it at the end.

Optimising these single-threaded sections of the build resulted in around 20
minutes being taken off the total runtime.

# Summary

We've gone from building 3,000 packages in 14 days in 2004, to building 14,000
packages in 4.5 hours in 2014.  We've achieved this through a number of
efforts:

* Distributed builds to scale across multiple hosts.
* Chrooted builds to scale on individual hosts.
* Tweaking `make -j` according to per-package effectiveness.
* Replacing scripts with C implementations in critical paths.
* Reducing forks by caching, batching commands, and using shell builtins where
  possible.
* Using faster shells.
* Parallelising single-threaded sections where possible.

What's next?  There are plenty of areas for further improvements:

* Improved scheduling to avoid builds with high `MAKE_JOBS` from sharing the
  same build zone.
* `make(1)` variable caching between sub-makes.
* Replace `/bin/sh` on illumos (ksh93) with dash (even if there is no appetite
  for this upstream, thanks to chroots we can just mount it as `/bin/sh` inside
  each chroot!)
* Dependency graph analysis to focus on packages with the most dependencies.
* Avoid the "long tail" by getting the final few large packages building as
  early as possible.
* Building in memory file systems if build size permits.
* Avoid building multiple copies of libnbcompat during bootstrap.

Many thanks to Jörg for writing pbulk and cwrappers, Google for sponsoring GSoC
so they could be written, the pkgsrc developers for all their hard work in
adding and updating packages, and of course Joyent for employing me to work on
this stuff.
