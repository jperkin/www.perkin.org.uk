---
layout: post
title: ZFS and NFS vs OSX
tags: [bug, nfs, osx, solaris, zfs]
---

gromit is my Solaris 10 server, chorlton is my OSX desktop. Explain this:

{% highlight console %}
root@gromit# zfs set sharenfs='anon=shared,sec=none' gromit/store
{% endhighlight %}

{% highlight console %}
root@gromit# zfs get sharenfs gromit/store
NAME          PROPERTY  VALUE                 SOURCE
gromit/store  sharenfs  anon=shared,sec=none  local
{% endhighlight %}

{% highlight console %}
user@chorlton$ ls /net/gromit/store
ls: cannot open directory /net/gromit/store/: Operation not permitted
{% endhighlight %}

{% highlight console %}
root@gromit# zfs set sharenfs='anon=shared' gromit/store
{% endhighlight %}

{% highlight console %}
user@chorlton$ ls /net/gromit/store
file1  file2
{% endhighlight %}

{% highlight console %}
user@chorlton$ touch /net/gromit/store/file3
touch: /net/gromit/store/file3: Permission denied
{% endhighlight %}

{% highlight console %}
root@gromit# zfs set sharenfs='anon=shared,sec=none' gromit/store
{% endhighlight %}

{% highlight console %}
user@chorlton$ touch /net/gromit/store/file3
user@chorlton$ echo $?
0
{% endhighlight %}
