---
layout: post
title: Fix Firefox URL double click behaviour
tags: [firefox, linux, osx]
---

One of the best things I find with OS X is the consistent and sane handling of
keyboard and mouse bindings.  Since having to move back to Linux for work I am
constantly frustrated that different applications all have their own idea of
what shortcuts to use.

One of the biggest annoyances was the mouse click behaviour in the browser URL
bar.  OS X behaviour is one click to position cursor, two clicks to select a
word, three clicks to select all.  I rely on this behaviour a lot as I
frequently copy/paste parts of URLs.

Thankfully that's one that can be fixed easily. Simply navigate to
<about:config> and double click on the `browser.urlbar.doubleClickSelectsAll`
key to set it to false.

One annoyance down, lots more to go..
