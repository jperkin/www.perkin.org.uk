---
layout: post
title: Solaris portability - flock()
tags: [illumos, smartos, solaris]
---

This is the first of what I hope will be a regular series of posts looking at
software portability when it comes to Solarish (Solaris, illumos, SmartOS etc.)
systems.  We will begin with `flock()`, as it's what I happen to have been
fixing today.

The most recent version of [tmux](http://tmux.sourceforge.net/) fails with the
following errors:

{% highlight text %}
client.c: In function 'client_get_lock':
client.c:81:2: warning: implicit declaration of function 'flock' [-Wimplicit-function-declaration]
client.c:81:20: error: 'LOCK_EX' undeclared (first use in this function)
client.c:81:20: note: each undeclared identifier is reported only once for each function it appears in
client.c:81:28: error: 'LOCK_NB' undeclared (first use in this function)
{% endhighlight %}

from this section of code:

{% highlight c %}
int
client_get_lock(char *lockfile)
{
        int lockfd;

        if ((lockfd = open(lockfile, O_WRONLY|O_CREAT, 0600)) == -1)
                fatal("open failed");

        if (flock(lockfd, LOCK_EX|LOCK_NB) == -1 && errno == EWOULDBLOCK) {
                while (flock(lockfd, LOCK_EX) == -1 && errno == EINTR)
                        /* nothing */;
                close(lockfd);
                return (-1);
        }

        return (lockfd);
}
{% endhighlight %}


This code is reasonably straight-forward, trying to create a lock on a file
descriptor, and if it isn't able to waits until the lock is released then
fails, ready for the calling function to retry.

However, the `flock()` routine is of BSD heritage and does not exist on
Solaris.  There used to be a compatability version as part of the `/usr/ucb`
environment, but that no longer exists in newer versions.

Thankfully, there is an alternative interface which has existed for as long as
`flock()` but with the added benefit of being standardised by POSIX and thus
much more portable - enter `fcntl()`!

Let's look at how the two are similar-but-different, and then show how we can
change this code to be more portable.

## flock() implementation

As we can see from the NetBSD manual page below, `flock()` is very simple, and
this is probably the main reason why people choose to use it over `fcntl()` for
file locking.

{% highlight text %}
NAME
     flock -- apply or remove an advisory lock on an open file

LIBRARY
     Standard C Library (libc, -lc)

SYNOPSIS
     #include <fcntl.h>

     #define   LOCK_SH   1    /* shared lock */
     #define   LOCK_EX   2    /* exclusive lock */
     #define   LOCK_NB   4    /* don't block when locking */
     #define   LOCK_UN   8    /* unlock */

     int
     flock(int fd, int operation);
{% endhighlight %}

There isn't much to it, you call `flock()` specifying either a shared or
exclusive lock, with an option to make the call non-blocking.  Afterwards you
unlock the previously held lock.

The tmux code in question uses `LOCK_NB` for the initial call, then if that
fails reverts to the default blocking operation so that the client can retry as
soon as the lock is released.

## Use fcntl() instead!

In contrast to `flock()`, setting up `fcntl()` is a bit more involved as it
allows finer-grained control over the locking.

### Set up struct flock

There is a `flock` structure which controls the lock, defined as:

{% highlight c %}
struct flock {
        off_t       l_start;    /* starting offset */
        off_t       l_len;      /* len = 0 means until end of file */
        pid_t       l_pid;      /* lock owner */
        short       l_type;     /* lock type: read/write, etc. */
        short       l_whence;   /* type of l_start */
};
{% endhighlight %}

So, let's set that up:

{% highlight c %}
int
client_get_lock(char *lockfile)
{
	int lockfd;
	struct flock lock;

	lock.l_start = 0;
	lock.l_len = 0;
	lock.l_type = F_WRLCK;
	lock.l_whence = SEEK_SET;
...
{% endhighlight %}

Setting `l_start` and `l_len` both to 0 means 'lock the entire file',
`l_whence` of `SEEK_SET` means we are setting absolute values rather than
relative, and we set `l_type` to be a write lock.  If we wanted a read lock,
we'd use `F_RDLCK` here instead.

Note that `l_pid` is only used for a `F_GETLK` operation - we are only
interested in attempting to set a lock, so it is left unset.

### Add fcntl() calls

The synopsis for `fcntl()` is:

{% highlight c %}
SYNOPSIS
     #include <fcntl.h>

     int
     fcntl(int fd, int cmd, ...);
{% endhighlight %}

and the commands available for file locking are (from BSD):

{% highlight c %}
#define F_GETLK         7               /* get record locking information */
#define F_SETLK         8               /* set record locking information */
#define F_SETLKW        9               /* F_SETLK; wait if blocked */
{% endhighlight %}

Note there is no 'clear lock' command.  To clear a lock, you use the `F_GETLK`
command with `l_type` set to `F_UNLCK`.

So, to show how we would rewrite the `flock()` instances to `fcntl()` instead,
I've put them together below:

{% highlight c %}
#ifdef __sun
	if (fcntl(lockfd, F_SETLK, &lock) == -1 && errno == EAGAIN) {
		while (fcntl(lockfd, F_SETLKW, &lock) == -1 && errno == EINTR)
			/* nothing */;
		close(lockfd);
		return(-1);
	}
#else
	if (flock(lockfd, LOCK_EX|LOCK_NB) == -1 && errno == EWOULDBLOCK) {
		while (flock(lockfd, LOCK_EX) == -1 && errno == EINTR)
			/* nothing */;
		close(lockfd);
		return (-1);
	}
#endif
{% endhighlight %}

As you can see, they are very similar, making it relatively straight-forward to
rewrite code to use the more portable `fcntl()`.

## An important note on semantics

There are two important difference between `flock()` and `fcntl()` you need to
be aware of which may affect a simple conversion:

* `fcntl()` locks are not held across a `fork()`, so you cannot pass locks down
  to child processes.

* The semantics of `fcntl()` are such that __any__ closure of a file descriptor
  in your application will release the locks held against that file.  This is
  best illustrated with a lock on `/etc/passwd` that gets released if you call
  `getpwname()` as that opens and closes the `/etc/passwd` file.

Generally such semantics do not apply, but you should be aware of them, and it
always pays to carefully read the manual pages, preferably those from BSD.

## flock() -> fcntl() cheat sheet

To aid your own conversions, here are some further examples (without error
checking for clarity) of `flock()` and `fcntl()` equivalents.

{% highlight c %}
#if defined(USING_FLOCK)

	/* Blocking */
	flock(lockfd, LOCK_SH);  // Shared (read) lock
	flock(lockfd, LOCK_EX);  // Exclusive (write) lock

	/* Non-blocking */
	flock(lockfd, LOCK_SH|LOCK_NB);  // Shared (read) lock
	flock(lockfd, LOCK_EX|LOCK_NB);  // Exclusive (write) lock

	/* Release */
	flock(lockfd, LOCK_UN):

#elif defined(USING_FCNTL)

	struct flock lock;

	lock.l_start = 0;
	lock.l_len = 0;
	lock.l_whence = SEEK_SET;

	/* Blocking */
	lock.l_type = F_RDLCK;
	fcntl(lockfd, F_SETLKW, &lock);  // Shared (read) lock
	lock.l_type = F_WRLCK;
	fcntl(lockfd, F_SETLKW, &lock);  // Exclusive (write) lock

	/* Non-blocking */
	lock.l_type = F_RDLCK;
	fcntl(lockfd, F_SETLK, &lock);  // Shared (read) lock
	lock.l_type = F_WRLCK;
	fcntl(lockfd, F_SETLK, &lock);  // Exclusive (write) lock

	/* Release */
	lock.l_type = F_UNLCK;
	fcntl(lockfd, F_GETLK, &lock);

#endif
{% endhighlight %}

## flock() wrapper

Alternatively, there is a `flock()` wrapper which is used by the NetBSD
toolchain, which you could include in a compatability library or so:

{% highlight c %}
int flock(int fd, int op) {
	int rc = 0;

#if defined(F_SETLK) && defined(F_SETLKW)
	struct flock fl = {0};

	switch (op & (LOCK_EX|LOCK_SH|LOCK_UN)) {
	case LOCK_EX:
		fl.l_type = F_WRLCK;
		break;

	case LOCK_SH:
		fl.l_type = F_RDLCK;
		break;

	case LOCK_UN:
		fl.l_type = F_UNLCK;
		break;

	default:
		errno = EINVAL;
		return -1;
	}

	fl.l_whence = SEEK_SET;
	rc = fcntl(fd, op & LOCK_NB ? F_SETLK : F_SETLKW, &fl);

	if (rc && (errno == EAGAIN))
		errno = EWOULDBLOCK;
#endif

	return rc;
}
{% endhighlight %}

It might be handy if the illumos folks merged this, it would immediate fix at
least 19 packages in the pkgsrc collection :)

## Summary

`flock()` is simpler, and retains locks across `fork()` and concurrent access
boundaries, but at the cost of portability.  Please try to use `fcntl()` where
possible, it isn't much harder to use, and makes your software run on more
platforms.
