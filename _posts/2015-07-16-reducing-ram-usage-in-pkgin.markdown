---
layout: post
title: Reducing RAM usage in pkgin
tags: [pkgsrc, smartos]
---

Recently I've had a number of users complain about pkgin running out of memory
when installing packages.  This turned into a nice example of how to use
DTrace to show memory allocations and help track down excessive use.

My test case was `pkgin -y install gcc47`.  This is usually one of the first
commands I run in a new SmartOS zone anyway, and as `gcc47` happens to be one
of the largest packages we ship it will help to exaggerate any memory
allocation.

### Trace heap allocations

As a first step I wanted to answer the question of how much memory was being
allocated for pkgin.  A simple and naive way to do this would be to run tools
such as `ps(1)` or `prstat(1)` (the SmartOS equivalent to `top(1)`) whilst
pkgin is running, and monitor the memory columns.  This may give you a very
rough idea of how much memory is being used, but it's not very accurate and
you may miss a large allocation just before the process exits.

Instead we can use DTrace to trace the `brk()` system calls and calculate the
exact amount of memory that has been allocated.  `brk()` is where libc memory
allocation functions such as `malloc()` end up on SmartOS, so by tracing that
single system call we can see exactly what has been allocated by the process.

Tracing `brk()` has the additional advantage of only showing heap growth.  If
we traced all the libc `*alloc()` calls, we would have to perform additional
analysis to determine whether we actually allocated more memory or whether an
existing allocation was reused.  For more information about the different ways
to trace memory allocations, see Brendan Gregg's excellent [Memory Flame
Graphs](http://www.brendangregg.com/FlameGraphs/memoryflamegraphs.html) page,
which is where many of the DTrace scripts in this post are based on.

I used the following DTrace script to output 3 pieces of information over the
lifetime of the target process:

* A quantized set of `brk()` allocation sizes.
* The total heap allocation.
* The number of `brk()` calls.

Comments are inline.  `pid == $target` ensures we only log `brk()` calls made
by the process we specify as opposed to all `brk()` calls across the entire
system, and `arg0` is the argument to the `brk()` system call.

{% highlight c %}
#!/usr/sbin/dtrace -qs

self int heap_ptr;

/*
 * The first brk() call by this application.  As we do not know the initial
 * value of the heap pointer, and thus be able to calculate the increase made
 * by this call, all we can do is save it.
 */
syscall::brk:entry
/pid == $target && !self->heap_ptr/
{
	self->heap_ptr = arg0;
}

/*
 * A subsequent brk() call.  Calculate the size of the allocation and
 * update our running totals.
 */
syscall::brk:entry
/pid == $target && self->heap_ptr != arg0/
{
	/* The heap grows up, so the size is simply (new addr - old addr) */
	this->size = arg0 - self->heap_ptr;

	/* A quantized distribution of allocation sizes. */
	@sizes["brk() allocation sizes"] = quantize(this->size);

	/* A running total of allocated bytes. */
	@bytes["Total bytes allocated"] = sum(this->size);

	/* The total number of calls to brk(). */
	@brks["Total number of brk() calls"] = count();

	/* Update our heap pointer for the next call. */
	self->heap_ptr = arg0;
}
{% endhighlight %}

Saving the script as `brkquantize.d` and running it gives us the following
output:

{% highlight console %}
: Start with a clean pkgin cache.
$ rm -rf /var/db/pkgin

: Ensure gcc47 is not installed, plus its dependency (binutils).
$ pkg_delete binutils gcc47

$ ./brkquantize.d -c "./pkgin-orig -py install gcc47"

  brk() allocation sizes
           value  ------------- Distribution ------------- count
           32768 |                                         0
           65536 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@       573
          131072 |@@                                       32
          262144 |@                                        23
          524288 |@@                                       39
         1048576 |                                         1
         2097152 |                                         2
         4194304 |                                         1
         8388608 |                                         2
        16777216 |                                         1
        33554432 |                                         0
        67108864 |                                         0
       134217728 |                                         1
       268435456 |                                         0

  Total bytes allocated                                     401752064
  Total number of brk() calls                                     675
{% endhighlight %}

Wow, that's a lot of memory.  383MB has been allocated on the heap, with one
of those allocations alone being between 128MB and 256MB.  No wonder users are
running out of memory!

This answers the questions regarding how much memory is being allocated, but
doesn't answer the question of what is causing it.  I have my suspicions at
this point (the gcc47 package tarball is 250MB, is pkgin caching the entire
thing?), but in order to prove my suspicion I want to produce a flame graph.

### Memory flame graph

If you didn't read the earlier link to Brendan Gregg's "Memory Flame Graphs"
page, go and do that now.  The reason for creating one is to see visually and
easily which code paths are responsible for the allocations.

To create the memory flame graph I used a slightly modified version of
Brendan's `brkbytes.d` with additional comments:

{% highlight c %}
#!/usr/sbin/dtrace -qs

self int prev;

syscall::brk:entry
/pid == $target/
{
	/* On entry, record the current heap pointer. */
	self->cur = arg0;
}

syscall::brk:return
/pid == $target && arg0 == 0 && self->prev/
{
	/* On return log the stack ordered by allocation size. */
	@[ustack()] = sum(self->cur - self->prev);
}

syscall::brk:return
/pid == $target && arg0 == 0/
{
	/* Save the previous heap pointer. */
	self->prev = self->cur;
}
{% endhighlight %}

Again we execute the script with `pkgin` as our target, after ensuring a clean
environment:

{% highlight console %}
$ rm -rf /var/db/pkgin/cache; pkg_delete binutils gcc47
$ ./brkbytes.d -c "./pkgin-orig -py install gcc47" >pkgin-orig.brkbytes

: Remove any pkgin output, we just want the stack traces.
$ vi pkgin-orig.brkbytes
{% endhighlight %}

Now we can use a couple of tools from Brendan's
[FlameGraph](https://github.com/brendangregg/FlameGraph) repository to convert
the stack traces into a flame graph:

{% highlight console %}
: Download Brendan Gregg's "FlameGraph" repository
$ git clone https://github.com/brendangregg/FlameGraph.git
$ cd FlameGraph

$ ./stackcollapse.pl ~/pkgin-orig.brkbytes \
    | ./flamegraph.pl \
        --countname=bytes \
        --title='"pkgin install" heap expansion - original' \
        --colors=mem --width=696 > ~/pkgin-orig-brkbytes.svg
{% endhighlight %}

The resulting SVG is below, you should be able to mouse-over the individual
elements for further details.

<div class="postimg">
  <object data="/files/images/pkgin-orig-brkbytes.svg" type="image/svg+xml">
  </object>
</div>

From the flame graph it's clear that the majority of allocations are coming
from `download_file()`, and we now have an accurate count of how much memory is
being allocated by that function.

We can further drill down on our hypothesis by comparing sizes.  The command we
are running is downloading and installing these two files:

{% highlight console %}
-rw-r--r--   1 root     root     9774130 Jul 10 10:47 binutils-2.24nb3.tgz
-rw-r--r--   1 root     root     261890422 Jul 10 10:47 gcc47-4.7.4.tgz
{% endhighlight %}

That's a total of 271,664,552 bytes.  According to the flame graph,
`download_file()` allocated 271,671,296 bytes.  So it seems highly likely it is
caching those files, the 6,744 byte descrepancy likely due to rounding to the
nearest page size (4K on SmartOS) and an additional page for something else.

Let's go to the source to confirm.

### Optimising `download_file()`

The `download_file()` function is reasonably straight-foward, and it's quite
clear that we are indeed reading the entire file into RAM before writing it out
to disk.  Source edited for clarity and added comments [(full version
here)](https://github.com/NetBSDfr/pkgin/blob/v0.8.0/download.c#L39..L136):

{% highlight c %}
Dlfile *
download_file(char *str_url, ...
{
...
	/* Get information about the remote file. */
	f = fetchXGet(url, &st, "");
...
	/*
	 * Allocate our Dlfile structure, as well as a buffer equal to the size
	 * of the remote file.
	 */
	buf_len = st.size;
	XMALLOC(file, sizeof(Dlfile));
        XMALLOC(file->buf, buf_len + 1);
...
	/* Download the file 1024 bytes at a time into our allocated buffer */
	while (buf_fetched < buf_len) {
		cur_fetched = fetchIO_read(f, file->buf + buf_fetched, 1024);
		buf_fetched += cur_fetched;
	}
...
	/* NUL-terminate the buffer and return the buffer and size. */
	file->buf[buf_len] = '\0';
	file->size = buf_len;
	return file;
}
{% endhighlight %}

On return to the caller it writes the returned buffer to a file descriptor and
then frees the buffer.

Optimising this is pretty straight-foward.  We will instead pass an open file
descriptor to a new `download_pkg()` function, which will stream to it directly
from each successful `fetchIO_read()` via a static 4K buffer.  The commit to
implement this is
[here](https://github.com/joyent/pkgin/commit/1511ccc94faa145af99632cc3bd58678cb85fa33).

Running `brkquantize.d` on the new implementation we see significantly reduced
memory usage:

{% highlight console %}
$ ./brkquantize.d -c "./pkgin-dlpkg -py install gcc47"

  brk() allocation sizes
           value  ------------- Distribution ------------- count
           32768 |                                         0
           65536 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@        511
          131072 |@@                                       32
          262144 |@                                        23
          524288 |@@@                                      43
         1048576 |                                         1
         2097152 |                                         2
         4194304 |                                         2
         8388608 |                                         1
        16777216 |                                         1
        33554432 |                                         0

  Total bytes allocated                                     134299648
  Total number of brk() calls                                     616
{% endhighlight %}

We've reduced our initial 383MB usage down to 128MB, and saved around 60 calls
to `brk()` in the process - a good start.

### Optimising `pkg_summary` handling

However 128MB still seems a lot for what the software is doing, can we do even
better?

Let's start with an updated memory flame graph to see where we stand with the
new version:

<div class="postimg">
  <object data="/files/images/pkgin-dlpkg-brkbytes.svg" type="image/svg+xml">
  </object>
</div>

It's clear that our `download_*()` functions are no longer on the scene, and
now the majority of the memory usage is caused by `update_db()`, accounting for
97MB.  This function handles fetching the remote `pkg_summary.bz2` file and
transferring its contents into pkgin's local sqlite3 database, which is then
used for local queries.

Analysing `update_db()` is a little more involved than `download_file()`, but
we can use flame graphs to help us identify which functions to look at.  In
this case we want to take a closer look at `decompress_buffer()` and
`insert_summary()`.

#### `decompress_buffer()`

After calling `download_file()` to fetch the the `pkg_summary.bz2` file, the
`decompress_buffer()` function is called to decompress it into memory and then
free the `download_file()` allocation.

However, why uncompress the entire file before parsing it?  Instead we can use
[libarchive](http://www.libarchive.org/) to stream the decompression and
process chunks at a time.  As it turns out pkgin already links against
libarchive but doesn't actually use it, so this is easy enough to add.

#### `insert_summary()`

While parsing the `pkg_summary` buffer, a set of `INSERT` statements are
constructed by this function.  However, again we are buffering the whole lot,
when instead we could just stream them one by one.

### Testing streaming updates

I made [some
changes](https://github.com/joyent/pkgin/commit/4c914a5159d5fc170bd05932fcdd833254863116)
to implement streaming updates at each end, reading chunks of our compressed
`pkg_summary` file and, once we'd read a complete record, stream an update to
the database.  Here's how the flamegraph looks afterwards:

{% highlight console %}
$ ./brkquantize.d -c "./pkgin-streamsum -y up"
  brk() allocation sizes
           value  ------------- Distribution ------------- count
           32768 |                                         0
           65536 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ 375
          131072 |                                         2
          262144 |                                         0
          524288 |                                         0
         1048576 |                                         1
         2097152 |                                         1
         4194304 |                                         0

  Total bytes allocated                                      30502912
  Total number of brk() calls                                     379
{% endhighlight %}

That's better, now just 29MB to perform an update.  However, that still seems
quite a lot, so let's generate an updated flame graph to see where the rest of
the memory is being used.

<div class="postimg">
  <object data="/files/images/pkgin-streamsum-brkbytes.svg" type="image/svg+xml">
  </object>
</div>

Ok, so it's clear the rest of the memory is being used by sqlite.  Anything we
can optimise there?

Turns out there is.  I looked through pkgin to see if it was setting any
non-default sqlite parameters, and the very first one immediately caught my
eye:

{% highlight c %}
static const char *pragmaopts[] = {
        "cache_size = 1000000",
{% endhighlight %}

The [manual](https://www.sqlite.org/pragma.html) says that this value is in
pages, with a default of 2000, and that the page size defaults to 1024 bytes,
so we're setting up a 976MB cache instead of the default 2MB.  This seems to be
rather larger than we need, so let's try just removing that `PRAGMA` and using
the default.

{% highlight console %}
$ ./brkquantize.d -c "./pkgin-nocache -y up"
  brk() allocation sizes
           value  ------------- Distribution ------------- count
           32768 |                                         0
           65536 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   55
          131072 |@                                        1
          262144 |                                         0
          524288 |                                         0
         1048576 |@                                        1
         2097152 |@                                        1
         4194304 |                                         0

  Total bytes allocated                                       9388032
  Total number of brk() calls                                      58
{% endhighlight %}

That's worked out very well, and we're now down to just 9MB, which seems
entirely reasonable to me.  One final flame graph:

<div class="postimg">
  <object data="/files/images/pkgin-nocache-brkbytes.svg" type="image/svg+xml">
  </object>
</div>

The majority of our usage is now handling the compressed `pkg_summary.bz2`
file.  There doesn't appear to be any way to stream a bzip2 file into
libarchive, so I think we're just about done.

## Final thoughts

Given we've changed a lot of code, and especially options around cache sizes,
how have they affected performance?  We can't be as accurate as with our DTrace
measurements here, but we can perform a real-world benchmark of timing a `pkgin
update` run against a localhost repository.  I ran each multiple times and took
the fastest result:

{% highlight console %}
: Original
$ time ./pkgin-orig up
real	0m42.401s
user	0m40.835s
sys	0m0.829s

: Modified
$ time ./pkgin-nocache up
real	0m9.912s
user	0m9.005s
sys	0m0.652s
{% endhighlight %}

Less RAM __and__ significantly faster?  I'll take that!

## Summary

By using DTrace and Flame Graphs we are able to quickly identify code paths
using large resources.  By streaming data instead of caching we are able to
significantly reduce the amount of RAM required and simultaneously boost
performance.

With these commits in place:

* [Stream package downloads](https://github.com/joyent/pkgin/commit/1511ccc94faa145af99632cc3bd58678cb85fa33)
* [Stream INSERTs](https://github.com/joyent/pkgin/commit/4c914a5159d5fc170bd05932fcdd833254863116)
* [Use default sqlite cache_size](https://github.com/joyent/pkgin/commit/9a0a365a4a8a52c279e266adca8af3a5a6f977e3)

the amount of RAM required to run `pkgin install gcc47` on a clean SmartOS
install reduces from 383MB to just 16MB.

I am hoping to get these changes in to the version of pkgin we ship for our
2015Q2 package sets, and will work to get these changes into upstream pkgin.
