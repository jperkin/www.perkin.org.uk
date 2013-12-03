---
layout: post
title: A node.js-powered 8-bit CPU - part one
tags: [8-bit, homebrew, nodejs]
---

This post is part one of a series, the other posts available are

* [Part two - shift registers](/posts/a-nodejs-powered-8-bit-cpu-part-two.html)
* [Part three - the CPU](/posts/a-nodejs-powered-8-bit-cpu-part-two.html)
* [Part four - putting it all together](/posts/a-nodejs-powered-8-bit-cpu-part-two.html)

## Introduction

As a child growing up in the 1980s, I was naturally drawn towards the 8-bit
computers of the day.  I spent most of my early childhood on my Atari 400 and
Amstrad CPC 6128, as well as being familiar with the Spectrum, Acorn Electron,
and BBC Model B computers owned by my friends.

Other than the occasional bit of BASIC and CP/M, however, I was not at the time
that interested in how they worked (I was too busy playing games), and so never
took the chance to learn assembly and electronics at that crucial early age.

This is something I've always regretted, and so recently I've found myself more
and more interested in revisiting those older systems.  While computers today
are far more capable and many orders of magnitude faster than those early
systems, they have also become significantly more complicated.  Nowadays, even
if you are curious about exactly how they work, they just are not as accessible
to answer those questions in the same way that computers from my childhood are.

As a result, there is today quite a large homebrew community, with people
building their own 8-bit systems.  One of my favourites is Matthew Sarnoff's
[Ultim809](http://www.msarnoff.org/6809/) computer, and his work inspired me to
have a go myself.

Realistically, with a busy job and a family, I'm never going to be able to get
to the level of Matthew's work, however I've had a lot of fun working on the
bits I've done so far, and wanted to share it so hopefully others can learn
too.

So, in these posts we're going to get to the stage where we can drive an 8-bit
CPU from a Raspberry Pi, using node.js (but any language will suffice).  To
start with, we need to introduce GPIO.

## GPIO

Quoting [Wikipedia](http://en.wikipedia.org/wiki/General-purpose_input/output):

"General-purpose input/output (GPIO) is a generic pin on an integrated circuit
(commonly called a chip) whose behaviour (including whether it is an input or
output pin) can be controlled (programmed) by the user at run time."

Essentially you can think of GPIO pins as small power switches which you can
turn on or off.  On the Raspberry Pi they provide 3.3V, and in our first simple
example we are going to control an LED from one.

Here's what you will need to follow along:

* A [Raspberry Pi](http://www.amazon.co.uk/Raspberry-Pi-RBCA000-1176JZF-S-Motherboard/dp/B008PT4GGC)
  (or similar system with user-programmable GPIO) running Linux.

* A [BreadBoard](http://www.amazon.co.uk/BB830-Solderless-Plug--BreadBoard-tie-points/dp/B0040Z4QN8).

* Some [LEDs](http://www.amazon.co.uk/SODIAL-Yellow-Assorted-Emitting-Diodes/dp/B00E34MNYU),
  preferably green, yellow, and red.

* Some [jumper wire](http://www.amazon.co.uk/Conductor-Female-Jumper-Color-Ribbon/dp/B00ATMHU52).

* Some [270 Ohm (Ω) resistors](http://www.amazon.co.uk/Carbon-Resistor-0-25w-270-270R/dp/B004S0X9YC)

Let's take a quick look at the bread board.  These allow fast and re-usable
construction of electronic circuits, and are laid out in rows - the verticals
down the side are for power (positive and negative), and each horizontal row is
for individual components.  In the diagram below, the power lines are indicated
by the red and blue boxes, and the component lines by the green boxes.

<div class="postimg">
  <a href="/files/images/nodejs-cpu-bread-board.jpg">
    <img src="/files/images/nodejs-cpu-bread-board.jpg" alt="Bread Board Layout">
  </a>
</div>

To construct the simplest possible electronic circuit, wire up the following:

* An LED vertically, with the anode (positive) above and the cathode (negative)
  below.  To determine the correct orientation the bottom side is usually flat,
  and/or the anode is longer.

* A jumper wire going from pin 1 on the Raspberry Pi (this is the +3.3V line)
  to a socket on the positive line.

* A jumper wire going from pin 6 on the Raspberry Pi (ground) to the blue
  (ground) power rail.

* A 270Ω resistor connecting the ground rail to the cathode line.  The resistor
  is required to reduce the voltage from 3.3V down to the 2.0V or so that the
  LED needs - without it the LED will likely burn brightly for a short time
  before blowing.

Doing this should give you a lit LED, and look something like this:

<div class="postimg">
  <a href="/files/images/nodejs-cpu-simple-led.jpg">
    <img src="/files/images/nodejs-cpu-simple-led.jpg" alt="Simple LED">
  </a>
</div>

I've added annotating arrows, with the positive arrows in red and negative
arrows in blue, showing the direction of current.

This is a good check that everything is working correctly, now let's move on to
make it software controlled.  To do that, move the red jumper wire from pin 1
to go to pin 11 instead.  This is known as `GPIO17` (there are different
numbering schemes for the pins depending on whether you use the physical layout
or the chipset's view - see
[http://elinux.org/images/2/2a/GPIOs.png](http://elinux.org/images/2/2a/GPIOs.png)
for the full layout).

## Software

To turn it on or off, let's get node up and running.  If you don't already have
it installed, grab the latest stable version for `linux-arm-pi` from
[http://nodejs.org/dist](http://nodejs.org/dist) (latest as of writing is
[v0.10.21](http://nodejs.org/dist/v0.10.21/node-v0.10.21-linux-arm-pi.tar.gz)):

{% highlight console %}
: You will need to be root to install and use the rpio module.
# curl -O http://nodejs.org/dist/v0.10.21/node-v0.10.21-linux-arm-pi.tar.gz
# tar zxf node-v0.10.21-linux-arm-pi.tar.gz -C /usr/local
# PATH=/usr/local/node-v0.10.21-linux-arm-pi/bin:$PATH
{% endhighlight %}

Next, install my [rpio](https://npmjs.org/package/rpio) module.  There are a
number of GPIO modules available, however mine appears to be the only one which
links against the [bcm2835](http://www.open.com.au/mikem/bcm2835/) library
rather than going via the much slower `/sys` file system interface.

{% highlight console %}
# npm install -g rpio
{% endhighlight %}

Finally, write this JavaScript to a file named `led-on.js`...

{% highlight javascript %}
// Load the rpio module
var rpio = require('rpio');

// Configure pin 11 (GPIO17) for output (i.e. read/write).
rpio.setOutput(11);

// Turn GPIO17 on, also known as 'high'.
rpio.write(11, 1);
{% endhighlight %}

...and run it...

{% highlight console %}
# node led-on.js
{% endhighlight %}

...which should result in the LED being lit.  You could then create an
`led-off.js` which is a copy of `led-on.js` except changing this:

{% highlight javascript %}
// Turn GPIO17 on (1), also known as 'high'.
rpio.write(11, 1);
{% endhighlight %}

to this:

{% highlight javascript %}
// Turn GPIO17 off (0), also known as 'low'.
rpio.write(11, 0);
{% endhighlight %}

and then we have a script which will turn the LED off.

For our final example, we can use `setInterval()` and `setTimeout()` to
implement a blinking LED:

{% highlight javascript %}
var rpio = require('rpio');

rpio.setOutput(11);

/*
 * Blink the LED quickly (10 times per second).  It is switched on every
 * 100ms, and a timeout is set for 50ms later to switch it off, giving us
 * the regular blink.
 */
setInterval(function blink() {
	rpio.write(11, 1);
	setTimeout(function ledoff() {
		rpio.write(11, 0);
	}, 50);
}, 100);
{% endhighlight %}

Here's a video of my setup running this script.

<div class="postimg">
  <iframe width="640" height="400" src="http://www.youtube.com/embed/tspC6ly4ZUw?rel=0" frameborder="0">
  </iframe>
</div>

This covers the introduction to GPIO and getting started with using node to
control pins.

If you wanted to stay at this level and experiment further, you could use a few
more of the GPIO pins to control additional LEDs, perhaps adding a yellow and a
green for some traffic lights.  I've [done
this](https://twitter.com/jperkin/status/310385020818825216) with my kids and
it's a great way for them to play with electronics.  My
[pilights](https://github.com/jperkin/pilights) repository on GitHub gives them
an easy to use shell script interface, with some example programs to get
started.

In the [next post](/posts/a-nodejs-powered-8-bit-cpu-part-two.html) we move on
to control something a little more complicated.
