---
layout: post
title: Fix input box keybindings in Firefox
tags: [firefox]
---

Those of us used to command line editing will no doubt have been frustrated
many times in Firefox when editing text in an input box and subconciously
hitting `ctrl-w` to `delete-word`, only to have the tab close and your work
deleted.

Thankfully there is a workaround to this.  It used to be a case of adding the
following to `.gtkrc`:

{% highlight text %}
gtk-key-theme-name = "Emacs"
{% endhighlight %}

However these days it's a gconf setting:

{% highlight text %}
$ gconftool-2 --set /desktop/gnome/interface/gtk_key_theme Emacs --type string
{% endhighlight %}

This will bind `ctrl-w` to `delete-word` when in an input box, but retain the
close tab binding elsewhere, a nice implementation of
[DWIM](http://en.wikipedia.org/wiki/DWIM).  See [this
page](http://kb.mozillazine.org/Emacs_Keybindings_%28Firefox%29) for more
information.
