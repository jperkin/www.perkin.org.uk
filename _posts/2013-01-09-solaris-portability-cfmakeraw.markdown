---
layout: post
title: Solaris portability - cfmakeraw()
tags: [illumos, smartos, solaris]
---

Converting from [`flock()` to
`fcntl()`](http://www.perkin.org.uk/posts/solaris-portability-flock.html)
unfortunately wasn't enough to get tmux to build on Solaris, there was one
additional failure:

{% highlight text %}
client.c: In function 'client_main':
client.c:246:3: warning: implicit declaration of function 'cfmakeraw' [-Wimplicit-function-declaration]

...

Undefined                       first referenced
 symbol                             in file
cfmakeraw                           client.o
ld: fatal: symbol referencing errors. No output written to tmux
collect2: error: ld returned 1 exit status
*** [tmux] Error code 1
{% endhighlight %}

Let's look at the code:

{% highlight c %}
	struct termios tio;
...
	cfmakeraw(&tio);
	tio.c_iflag = ICRNL|IXANY;
	tio.c_oflag = OPOST|ONLCR;
...
{% endhighlight %}

Running `man cfmakeraw` on my OSX laptop I can read what this function does,
and where it is implemented (edited for brevity):

{% highlight text %}
SYNOPSIS
     void
     cfmakeraw(struct termios *termios_p);

DESCRIPTION
     The cfmakeraw() function sets the flags stored in the termios structure
     to a state disabling all input and output processing, giving a ``raw I/O
     path''.

STANDARDS
     The cfmakeraw() and cfsetspeed() functions, as well as the TCSASOFT option
     to the tcsetattr() function are extensions to the IEEE Std 1003.1-1988
     (``POSIX.1'') specification.
{% endhighlight %}

Ok, so all it's doing is setting some additional flags in the `tio` structure,
and a quick search in the [NetBSD
OpenGrok](http://opengrok.netbsd.org/xref/src/lib/libc/termios/cfmakeraw.c)
gives us their implementation (again edited for brevity):

{% highlight c %}
void
cfmakeraw(struct termios *t)
{
...
	t->c_iflag &= ~(IMAXBEL|IGNBRK|BRKINT|PARMRK|ISTRIP|INLCR|IGNCR|ICRNL|IXON);
	t->c_oflag &= ~OPOST;
	t->c_lflag &= ~(ECHO|ECHONL|ICANON|ISIG|IEXTEN);
	t->c_cflag &= ~(CSIZE|PARENB);
	t->c_cflag |= CS8;
...
}
{% endhighlight %}

All that's left is to patch the tmux code to set those flags.  A good patch
would add a feature test to the tmux autoconf setup and/or provide a
compatability macro, but in this case I simply add a Solaris-specific section
to the code: 

{% highlight c %}
	struct termios tio;
...
#ifdef __sun
	tio.c_iflag &= ~(IMAXBEL|IGNBRK|BRKINT|PARMRK|ISTRIP|INLCR|IGNCR|ICRNL|IXON);
	tio.c_oflag &= ~OPOST;
	tio.c_lflag &= ~(ECHO|ECHONL|ICANON|ISIG|IEXTEN);
	tio.c_cflag &= ~(CSIZE|PARENB);
	tio.c_cflag |= CS8;
#else
	cfmakeraw(&tio);
#endif
	tio.c_iflag = ICRNL|IXANY;
	tio.c_oflag = OPOST|ONLCR;
...
{% endhighlight %}

## Summary

`cfmakeraw()` is an extension to POSIX and thus not fully portable.  If you use
it, please consider including a compatability version for systems which do not
implement it.
