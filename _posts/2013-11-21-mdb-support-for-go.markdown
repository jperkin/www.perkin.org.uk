---
layout: post
title: MDB support for Go
tags: [go, illumos, mdb, smartos]
---

Last week was Joyent Engineering's inaugural hackathon, where we spent a couple
of days together in San Francisco working in small teams on projects which
interested us and were at least in some way relevant to our business.

Whilst the obvious choice for me would have been to work on something which
used Manta for pkgsrc analysis (no shortage of ideas or potential there), I
wanted to take advantage of being in the same room as my illustrious co-workers
and work on something a bit more low-level and personally challenging.

For the past few months Aram Hăvărneanu has been doing some amazing work
porting [Go to SunOS](https://bitbucket.org/4ad/go-sunos), and we wanted to
help out.  So, while [Bryan](http://dtrace.org/blogs/bmc/) and
[Josh](http://blog.sysmgr.org/) got stuck in with Go core and
[Brendan](http://dtrace.org/blogs/brendan/) started cooking up some Go-related
DTrace, I ventured into MDB land to add support for Go stack traces.

At this point you should go and read [Dave](http://dtrace.org/blogs/dap/)'s
excellent [post on stack traces](http://dtrace.org/blogs/dap/2013/11/20/understanding-dtrace-ustack-helpers/),
as it provides a lot of background material and was super helpful for me whilst
working on this.  Done?  Ok.

## C Stack Traces

Let's start by looking at a contrived example in C.  Here is the code:

{% highlight c %}
#include <stdio.h>

int printout(int num1, int num2)
{
	printf("%d -> %d\n", num1, num2);
}

int addone(int num)
{
	printout(num, num + 1);
}

int main(int argc, char *argv[])
{
	addone(atoi(argv[1]));
}
{% endhighlight %}

Compile it with no optimisations to ensure we do not lose any functions to
inlining.  The `-g` isn't strictly necessary for these examples, but is good
practise nonetheless.

{% highlight bash %}
$ gcc -O0 -g test.c -o test-c
{% endhighlight %}

Now we can show a stack trace using MDB.  Comments inline:

{% highlight text %}
$ mdb ./test-c

#
# Print a disassembly of the printout() function.  We want to set a break
# point where the stack pointer (`%rsp`) and frame pointer (`%rbp`) have been
# callee saved, so that the stack trace is accurate.  If we simply set the
# break point to the beginning of printout() the stack trace would not show
# the addone() call.
#
# I include the '-b' argument to ::dis to show real address in addition to
# the symbolic ones.
#
> printout::dis -b
401058    printout:             pushq  %rbp
401059    printout+1:           movq   %rsp,%rbp
40105c    printout+4:           subq   $0x10,%rsp
401060    printout+8:           movl   %edi,-0x4(%rbp)
401063    printout+0xb:         movl   %esi,-0x8(%rbp)
401066    printout+0xe:         movl   -0x8(%rbp),%edx
401069    printout+0x11:        movl   -0x4(%rbp),%eax
40106c    printout+0x14:        movl   %eax,%esi
40106e    printout+0x16:        movl   $0x401130,%edi
401073    printout+0x1b:        movl   $0x0,%eax
401078    printout+0x20:        call   -0x21d   <PLT:printf>
40107d    printout+0x25:        leave
40107e    printout+0x26:        ret

#
# Set a break point of the call to printf() within printout()
#
> printout+20::bp

#
# Run the program with an argument of '6'.
#
> ::run 6
mdb: stop at printout+0x20
mdb: target stopped at:
printout+0x20:  call   -0x21d   <PLT:printf>

#
# Print out a stack trace, including stack addresses ('$C').  Using '$c' would
# show just the function calls.
#
> $C
fffffd7fffdff310 printout+0x20()
fffffd7fffdff330 addone+0x1d()
fffffd7fffdff350 main+0x2e()
fffffd7fffdff360 _start+0x6c()

#
# Print out the status of all registers.
#
> ::regs
%rax = 0x0000000000000000       %r8  = 0xfffffd7fffdff596
%rbx = 0xfffffd7fff3fafd8       %r9  = 0xfffffd7fff331ee3
%rcx = 0x0000000000000000       %r10 = 0x0000000000000000
%rdx = 0x0000000000000007       %r11 = 0x00000000000000c0
%rsi = 0x0000000000000006       %r12 = 0x0000000000000000
%rdi = 0x0000000000401130       %r13 = 0x0000000000000000
                                %r14 = 0x0000000000000000
                                %r15 = 0x0000000000000000

%cs = 0x0053    %fs = 0x0000    %gs = 0x0000
%ds = 0x0000    %es = 0x0000    %ss = 0x004b

%rip = 0x0000000000401078 printout+0x20
%rbp = 0xfffffd7fffdff310
%rsp = 0xfffffd7fffdff300

%rflags = 0x00000286
  id=0 vip=0 vif=0 ac=0 vm=0 rf=0 nt=0 iopl=0x0
  status=<of,df,IF,tf,SF,zf,af,PF,cf>

%gsbase = 0x0000000000000000
%fsbase = 0xfffffd7fff172a40
%trapno = 0x3
   %err = 0x0

#
# Print out the contents of the stack in memory.
#
> 0xfffffd7fffdff300,70::dump
                   \/ 1 2 3  4 5 6 7  8 9 a b  c d e f  v123456789abcdef
fffffd7fffdff300:  00000000 00000000 07000000 06000000  ................
fffffd7fffdff310:  30f3dfff 7ffdffff 9c104000 00000000  0.........@.....
fffffd7fffdff320:  50f3dfff 7ffdffff 280936ff 06000000  P.......(.6.....
fffffd7fffdff330:  50f3dfff 7ffdffff cc104000 00000000  P.........@.....
fffffd7fffdff340:  78f3dfff 7ffdffff 78f3dfff 02000000  x.......x.......
fffffd7fffdff350:  60f3dfff 7ffdffff ec0e4000 00000000  `.........@.....
fffffd7fffdff360:  00000000 00000000 00000000 00000000  ................

#
# Print the contents of %rdi.
#
> 401130::dump
         \/ 1 2 3  4 5 6 7  8 9 a b  c d e f  v123456789abcdef
401130:  2564202d 3e202564 0a000000 00000000  %d -> %d........

#
# Print the instruction pointers saved on the stack, with one instruction
# either side for context.
#
> 40109c::dis -b -n 1
401097    addone+0x18:                          call   -0x44    <printout>
40109c    addone+0x1d:                          leave
40109d    addone+0x1e:                          ret
> 4010cc::dis -b -n 1
4010c7    main+0x29:                            call   -0x4d    <addone>
4010cc    main+0x2e:                            leave
4010cd    main+0x2f:                            ret
{% endhighlight %}

From the output we can match up a few things:

* The instruction pointer `%rip` is set to our break point, and you can see
  both the real (`0x401078`) and the symbolic (`printout+0x20`) addresses.

* The arguments to `printf()` are passed in the registers, with `%rdx` and
  `%rsi` containing the integers we are printing, and `%rdi` containing a
  pointer to the string "`%d -> %d`" which we can see using `::dump`.

* The stack contains arguments (`7`, `6`), instruction pointers (`40109c`,
  `4010cc`) and frame pointers (`fffffd7fffdff330`, `fffffd7fffdff330`).

If you are wondering where I am getting those addresses from, note that this is
on x86 which is little-endian, and so you need to read each byte backwards -
that is, if you have a dump line which contains a 64-bit value, a 32-bit value,
a 16-bit value and two 8-bit values, then:

{% highlight text %}
xxxxxxxxxxxxxxxx:  78f3dfff 7ffdffff 78f3dfff 0207410d  ................
{% endhighlight %}

corresponds to:

* 0xfffffd7fffdff378 (64-bit)
* 0xffdff378 (32-bit)
* 0x0702 (16-bit)
* 0x41 (8-bit)
* 0x0d (8-bit)

Playing around with MDB like this was super helpful for me to get a visual
representation of memory, and how functions and arguments are passed around.

Thanks to the frame pointers being saved on the stack, we are able to easily
get useful stack traces by simply following them and printing each frame in
turn.

At this point it's worth mentioning the infamous GCC argument
`-fomit-frame-pointer`.  If you are of a certain age, you may remember some
Linux distributions using this flag in an attempt to make programs faster.
What happens is that instead of using the frame pointer to record valuable
information about where we came from, it is instead used as a general purpose
register, and the stack information is lost.

This can be verified pretty easily:

{% highlight bash %}
$ gcc -O0 -g -fomit-frame-pointer test.c -o test-nofp

$ mdb ./test-nofp

> printout+0x20::bp

> ::run 6
mdb: stop at printout+0x20
mdb: target stopped at:
printout+0x20:  call   -0x225   <PLT:printf>

> $C
fffffd7fffdff350 printout+0x20()

> ::regs ! grep 'r[ibs]p'
%rip = 0x0000000000401068 printout+0x20
%rbp = 0xfffffd7fffdff350
%rsp = 0xfffffd7fffdff2f0
{% endhighlight %}

That's all we have.  `%rbp` is no longer used to record the previous `%rsp`,
and so after printing the current instruction, we have nowhere else to go, and
the stack is useless.

Friends don't let friends go without their frame pointers.  There is very
little to suggest that the extra register provides any performance benefits,
and the cost is way too high.  Just Say No.

## Go Stack Traces

So, let's look at Go.  One of the nice things about Go is that it compiles
programs down to a self-contained binary, which can then be copied around and
executed.  This may lead you to think that stack traces will simply work, as
there is no dynamic runtime stuff going on.  Well, let's see.

Let's start with a comparative program to the one above, written in Go.

{% highlight go %}
package main

import (
	"fmt"
	"os"
	"strconv"
)

func printout(num1 int, num2 int) {
	fmt.Printf("%d -> %d\n", num1, num2)
}

func addone(num int) {
	printout(num, num + 1)
}

func main() {
	num, _ := strconv.Atoi(os.Args[1])
	addone(num)
}
{% endhighlight %}

Compile it and start MDB.

{% highlight bash %}
$ go build -o test-go test.go
$ mdb ./test-go
{% endhighlight %}

The first thing we notice is that we do have symbols, which is good!  We can
also show the first few instructions of our `printout()` function:

{% highlight text %}
> ::nm ! egrep 'addone|printout'
0x0000000000400c00|0x00000000000000cb|FUNC |GLOB |0x0  |1       |main.printout
0x0000000000400cd0|0x0000000000000034|FUNC |GLOB |0x0  |1       |main.addone

> main.printout::dis -b -n 8
400c00    main.printout:                        movq   %fs:-0x10,%rcx
400c09    main.printout+9:                      cmpq   (%rcx),%rsp
400c0c    main.printout+0xc:                    ja     +0x7     <main.printout+0x15>
400c0e    main.printout+0xe:                    call   +0x2078d <runtime.morestack16>
400c13    main.printout+0x13:                   jmp    -0x15    <main.printout>
400c15    main.printout+0x15:                   subq   $0x80,%rsp
400c1c    main.printout+0x1c:                   leaq   0x60(%rsp),%rdi
400c21    main.printout+0x21:                   xorq   %rax,%rax
400c24    main.printout+0x24:                   movq   $0x4,%rcx
{% endhighlight %}

However, note that the frame pointer is never saved - the function just goes
right ahead and tries to allocate more stack.  And, indeed, if we set a
breakpoint and run the program, we do not get a useful stack trace.

{% highlight text %}
> main.printout::bp

> ::run 6
mdb: stop at main.printout
mdb: target stopped at:
main.printout:  movq   %fs:-0x10,%rcx

> $C
8000000000000000 main.printout()
{% endhighlight %}

The problem is that Go uses a completely different calling convention, so the
usual method of following frame pointers does not work.  At this point we would
normally be stuck, however Go does provide enough information in the binary for
us to calculate the stack in a different way.  We just need to dig it out.

First, let's take a look to see what the stack does contain.  I deliberately
set a breakpoint to the start of the `printout()` function so that the stack
did not contain any local variables for that function.

{% highlight text %}
> ::regs ! grep rsp
%rsp = 0xfffffd7ffef8ff00

> 0xfffffd7ffef8ff00,b0::dump
                   \/ 1 2 3  4 5 6 7  8 9 a b  c d e f  v123456789abcdef
fffffd7ffef8ff00:  ff0c4000 00000000 06000000 00000000  ..@.............
fffffd7ffef8ff10:  07000000 00000000 610d4000 00000000  ........a.@.....
fffffd7ffef8ff20:  06000000 00000000 01000000 00000000  ................
fffffd7ffef8ff30:  06000000 00000000 00000000 00000000  ................
fffffd7ffef8ff40:  00000000 00000000 ee364100 00000000  .........6A.....
fffffd7ffef8ff50:  c0764100 00000000 00000000 00000000  .vA.............
fffffd7ffef8ff60:  00000000 00000000 00000000 01000000  ................
fffffd7ffef8ff70:  ffffffff ffffffff 00000000 00000000  ................
fffffd7ffef8ff80:  084e5600 00000000 00000000 00000000  .NV.............
fffffd7ffef8ff90:  00000000 00000000 f05b4100 00000000  .........[A.....
fffffd7ffef8ffa0:  00000000 00000000 00000000 00000000  ................
{% endhighlight %}

A few things stood out here.  Knowing the function arguments in advance allows
us to spot the various `7`, `6` and `1` integers being passed, so we can take a
guess that the other addresses refer to functions, and we can confirm this with
MDB:

{% highlight text %}
> 400cff::dis -b -n 1
400cfa    main.addone+0x2a:                     call   -0xff    <main.printout>
400cff    main.addone+0x2f:                     addq   $0x10,%rsp
400d03    main.addone+0x33:                     ret

> 400d61::dis -b -n 1
400d5c    main.main+0x4c:                       call   -0x91    <main.addone>
400d61    main.main+0x51:                       addq   $0x28,%rsp
400d65    main.main+0x55:                       ret

> 4136ee::dis -b -n 1
4136e9    runtime.main+0xe9:                    call   -0x129de <main.main>
4136ee    runtime.main+0xee:                    cmpl   $0x0,0x573868
4136f6    runtime.main+0xf6:                    je     +0x20    <runtime.main+0x118>
{% endhighlight %}

So, we can dig through the stack and find functions and arguments.  However,
because functions can have differing argument lengths, we can't step over a
fixed size - we need to know how many arguments a function takes, so that we
know how much of the stack to skip in order to get to the next function.

Thankfully, Go provides us with the answer, in the form of the pclntab.

The pclntab is written into the binary by the Go linker, and contains useful
information about each function.  The format is described in [this
document](https://docs.google.com/document/d/1lyPIbmsYbXnpNj57a261hgOYVpNRcgydurVQIyZOz_o/pub)
for Go 1.2, which is the version we are targetting.

Here is the beginning of the pclntab:

{% highlight text %}
> pclntab,50::dump
         \/ 1 2 3  4 5 6 7  8 9 a b  c d e f  v123456789abcdef
524840:  fbffffff 00000108 4d060000 00000000  ........M.......
524850:  000c4000 00000000 f0640000 00000000  ..@......d......
524860:  d00c4000 00000000 58650000 00000000  ..@.....Xe......
524870:  100d4000 00000000 b0650000 00000000  ..@......e......
524880:  700d4000 00000000 10660000 00000000  p.@......f......
{% endhighlight %}

If you read the document above you can see and compare the pclntab header
format - we start with the magic number `0xfffffffb`, followed by `0x0000`.
Then `0x01` for the instruction size quantum and `0x08` for the size of a
pointer (both accurate for 64-bit x86).  After that we have `0x064d` as the
64-bit size of the function symbol table.

After the header we have pairs of function addresses to function offsets within
the pclntab.  So, for example, we start with `0x400c00`, for which the
information is stored at offset `0x64f0` within the pclntab.  Decoding the data
at this offset gives us the details we need.

At this point we need to dig through the Go source code to find how this
information is stored, and thankfully we can mostly lift it directly into our
MDB module.

## MDB Module

The current version of the MDB module is
[here](https://github.com/joyent/mdb_go), you may want to follow along there.

We can start by transplanting the layouts for the pclntab and Go function
information.

{% highlight c %}
/*
 * The pclntab header.
 */
struct pctabhdr {
	uint32_t magic;		/* 0xfffffffb */
	uint16_t zeros;		/* 0x0000 */
	uint8_t quantum;	/* 1 on x86, 4 on ARM */
	uint8_t ptrsize;	/* sizeof(uintptr_t) */
	uintptr_t tabsize;	/* size of function symbol table */
};

/*
 * The function -> offset entries.
 */
typedef struct go_func_table {
	uintptr_t entry;
	uintptr_t offset;
} go_functbl_t;

/*
 * The information about each function which is stored in the pclntab.
 */
typedef struct go_func {
	uintptr_t entry;
	uint32_t nameoff;
	uint32_t args;
	uint32_t frame;
	uint32_t pcsp;
	uint32_t pcfile;
	uint32_t pcln;
	uint32_t npcdata;
	uint32_t nfuncdata;
} go_func_t;
{% endhighlight %}

Once we have that, we can do the following:

* Start by loading the pclntab and checking it is valid in `configure()`.  If
  it is good, we store its location and size.

* Get the previous instruction from the top of the stack.  In our example this
  is `0x400cff`, and is done using `load_current_context()` which reads the
  current value of `%rsp`.

* Perform a binary search through the `go_functbl_t` entries for that address.
  If our address is larger than the current lookup but less than the next one,
  we have a match.  This is implemented in `findfunc()`.

* Read in the function information into our `go_func_t` using `pcvalue()` and
  the information stored at our function offset.

This is implemented with the `::goframe` dcmd, which we can use after loading
the new `go.so` module.

{% highlight text %}
> ::load /root/mdb_go/go.so
Configured Go support

> ::goframe
fffffd7fffdfdf30 = {
	entry = 400cd0,
	nameoff = 6590 (main.addone),
	args = 8 (len=1),
	frame = 18,
	pcsp = 659d (delta=16),
	pcfile = 65a4 (/root/test.go),
	pcln = 65a7 (15),
	npcdata = 0,
	nfuncdata = 2,
}
{% endhighlight %}

Note that we have some additional useful information here, including the
filename and the line number.  I implemented a `-p name` argument which pretty
prints this information:

{% highlight text %}
> ::goframe -p name
main.addone(0x6)
	(in /root/test.go line 15)
{% endhighlight %}

The final part of the puzzle is to dig out the argument length and skip over
that size, so that we can get to the next function.  This is pretty
straight-forward, we just skip over the size of the `frame` entry.

With this in place we can implement an MDB "walker", which walks our stack and
prints each address.  MDB makes this really easy, and is implemented in
`walk_goframes_init` and `walk_goframes_step`, which simply describe how to
find the first frame and then how to find each subsequent frame.

{% highlight text %}
> ::walk goframe
fffffd7ffef8ff00
fffffd7ffef8ff18
fffffd7ffef8ff48
fffffd7ffef8ff98
fffffd7ffef8ffa8
{% endhighlight %}

And, for the finale, we show the beautiful modularity of MDB by simply piping
those addresses to the `::goframe` dcmd:

{% highlight text %}
> ::walk goframe | ::goframe -p name
main.addone(0x6)
	(in /root/test.go line 15)
main.main()
	(in /root/test.go line 20)
runtime.main()
	(in /root/go-sunos/src/pkg/runtime/proc.c line 199)
runtime.goexit()
	(in /root/go-sunos/src/pkg/runtime/proc.c line 1395)
{% endhighlight %}

And hey presto, we have a stack trace.

## Future Work

So, as you may have noticed, I cheated a little by setting a break point to the
start of the `printout()` function.  This allows us to print a full stack
trace, including the current instruction, using the `::gostack` dcmd:

{% highlight text %}
> ::gostack -p name
main.printout(0x6, 0x7)
	(in /root/test.go line 9)
main.addone(0x6)
	(in /root/test.go line 15)
main.main()
	(in /root/test.go line 20)
runtime.main()
	(in /root/go-sunos/src/pkg/runtime/proc.c line 199)
runtime.goexit()
	(in /root/go-sunos/src/pkg/runtime/proc.c line 1395)
{% endhighlight %}

However, if we set the break point to the point where we call `fmt.Printf()`:

{% highlight text %}
> main.printout+0xb5::bp

> ::run 6
mdb: stop at main.printout+0xb5
mdb: target stopped at:
main.printout+0xb5:     call   +0x24a26 <fmt.Printf>

> ::gostack -p name
main.printout(0x9, 0xfef8fee0)
	(in /root/test.go line 10)
{% endhighlight %}

We are unable to walk the stack, and the arguments to `main.printout()` are
incorrect, due to `main.printout()` allocating a bunch of the stack for its
local variables which messes up our offsets.

I need to figure out how to calculate these reliably, plus there are a bunch of
cleanups to do in the module.  It's also likely that there are lots of edge
cases where things will break.

It's also likely that the format of the symbol tables will change, so we will
need to track changes upstream.

Finally, the most useful work we can do based on this initial implementation
would be to translate the same information into a DTrace ustack helper.  This
would allow us to dynamically instrument running Go programs, and do all sorts
of useful performance and debugging analysis.  The information is all there,
and we can in theory get to it using `uregs[]`, but there are a number of
challenges to overcome first, most notably trying to hook into the Plan9 linker
which currently rejects DTrace ELF sections.  Help in this area would be
appreciated :)

Hopefully this was a useful introduction to MDB and how to implement support
for esoteric languages.  I welcome any feedback and improvements.
