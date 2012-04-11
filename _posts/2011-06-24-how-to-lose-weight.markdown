---
layout: post
title: How to lose weight
tags: [weightloss]
---

This year I set myself a target to get back to my pre-marital weight.  Back in
2001 I was 90kg, but over the past decade I'd steadily gone up and for quite a
few years had hovered around 100kg.

I'm a bit of a perfectionist, and like shiny graphs, so from Jan 1st this year
I weighed myself every day on the Wii Fit, and kept a record of my progress.
This morning I was finally under 90kg.  Here's how things have gone thus far:

<div class="postimg">
  <img src="http://www.perkin.org.uk/files/images/weight-jun11.png" alt="My weight loss between 1st January 2011 and 24th June 2011">
</div>

And for the geeks, my gnuplot script, assuming an input file named `weight.txt` containing lines of the format `"%Y-%m-%d <weight>"`:

{% highlight gnuplot %}
set terminal png size 640, 400
set output "weight-jun11.png"
set xdata time
set timefmt "%Y-%m-%d"
set format x "%b"
set xlabel 'Date'
set ytics 2
set ylabel 'Weight (kg)'
set multiplot
plot 'weight.txt' using 1:2 title 'Weight' with lines linecolor 2
{% endhighlight %}

## My three step plan for losing weight

The interwebs are awash with a million different ways to lose weight, and there
are thousands of companies who will gladly accept large chunks of your cash in
order to provide you with their expert opinion on how to do it.  This is my
three-step plan, and you can have it for free:

1. Eat less.
2. Eat less!
3. Profit!!!

Really, that's it.  It's not rocket science, after all.  If you eat less stuff
(especially saturated fat and sugar), there is less excess for your body to
store as fat, and thus over time you weigh less as your body starts to use up
the excess you have stored.

Here's some things I did to achieve this.

### Eat less

The basic aim.  For me this was mainly about reducing my portion size.

Previously, I'd eat a massive bowl of cereal in the morning. which I thought
was a good thing as everyone always says to ensure you have a good breakfast.
However I was eating more than my body needed and as a consequence it was
likely storing up the excess.

Also at meal times I'd usually serve myself a full plate, and always feel that
I needed to finish it.  I liked feeling full.  However, again, this likely just
meant I was eating more than I needed, and I found that just by serving less
food I was still satisfying my hunger but with less excess.

After a relatively short period of time I found that by avoiding these large
meals, I needed less to feel full – as if my stomach had shrunk and gotten used
to the reduced size.  This was a great positive feedback loop, as it massively
helped avoid the temptation to snack between meals.

### Cut down on sugar/fat

I realise this can be hard for some people, I found it relatively easy but as
you can see on the graph above there are some upward trends, which were mainly
when I went to visit my parents, who have a cupboard full of chocolates,
crisps, cakes, sweets, etc, and I find it really hard not to have at least one
or two fake Lidl snickers bars per day!

However, also note that after an upward trend, I lost the weight again pretty
quickly, so don't worry too much about a few days of eating junk, I actually
noticed how bad I felt afterwards after getting used to a reduced sugar/fat
intake, and that provided good incentive to cut down again.

Some practical things I did:

* Stopped putting sugar in tea/coffee.  I've since regressed, but it was
  helpful to do this for a while, and definitely helped wean my body off
  desiring sugar.

* Avoided snacking on crisps, chocolate, biscuits, etc.  When you work from
  home this can be difficult, but I found it helped to ensure they weren't in
  the house to begin with, and that we were stocked up on bananas, apples, and
  other less sugary/fatty snacks.

* Used a fine cheese grater when making sandwiches, beans on toast, etc.
  Previously I'd put a good few slabs of cheese in, when I didn't really need
  that quantity.  The fine grater ensured I still got the taste, but with less
  quantity.

* Bought reduced fat mayonnaise, margarine, etc.  These actually taste pretty
  good these days, and in a sandwich with lots of fresh cucumber, tomato, salad
  etc you don't notice the difference

All these things helped to lose weight and, in a similar manner to the 'eating
less' part, trained my body to not require them as much as it used to – and
actually, to noticeably feel worse if ever I regressed, which made getting back
on track very easy.

### Weigh myself daily

It seems this is generally not recommended, and advice is that you should weigh
yourself weekly (at the same time each week).  Logically this doesn't make
sense to me, as a geek it's obvious that the more data points you have, the
better.  Your body weight can fluctuate quite a lot from day to day especially
with regards to how much liquid you have drunk, and if you are only weighing
yourself once per week you could get caught out by a daily spike.

Aside from the geek factor of a better graph resolution, I also prefer daily
weighing as it provides me, as a perfectionist, with incentives both ways.  If
I weigh less compared to the previous day, I feel good that I am achieving my
aim, and am encouraged to continue.  If I weigh more, it's a warning that I may
have eaten too much, and I am then motivated to be more careful that day.

Weighing daily also helps to just keep your mind reminded of the task, plus if
you're on the Wii Fit already you might be tempted to do some exercise :)

## Next steps

I'm not content to stay here, the next plan is to get closer to my ideal BMI
weight which is around 80kg.  This is likely to be much harder, as there is
less excess fat for me to get rid of now.  However, one thing I haven't done so
far is increase the amount of exercise I do, and there is definitely room for
improvement there!

Hopefully I can provide another update later this year and perhaps be around
85kg.
