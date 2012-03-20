---
layout: post
title: Set up anonymous FTP upload on Oracle Linux
tags: [oracle-linux, selinux, vsftpd]
---

Just because this took a little longer than I expected, here's a quick howto
for setting up an anonymous FTP drop-off on Oracle Linux, which I use as a
simple way to transfer files out of my Virtual Machines.

## Install vsftpd

{% highlight console %}
$ sudo yum -y install vsftpd
{% endhighlight %}

## Configure iptables

As FTP is a more complicated protocol than most, there is a special netfilter
module required in order to correctly keep track of connections.

{% highlight console %}
# You will perhaps want to change the insert number here.
$ sudo iptables -I INPUT 4 -m state --state NEW -p tcp --dport 21 -j ACCEPT
$ sudo /etc/init.d/iptables save
{% endhighlight %}

Add `nf_conntrack_ftp` to `IPTABLES_MODULES`

{% highlight console %}
$ sudo vi /etc/sysconfig/iptables-config
{% endhighlight %}

Then load the module rather than reboot

{% highlight console %}
$ sudo modprobe nf_conntrack_ftp
{% endhighlight %}

## Create /incoming

Create `/incoming` area and ensure it has the correct file permissions and
SELinux context.  This is the bit which had me stumped for a little while, as I
didn't know about `allow_ftpd_anon_write`, and while I normally just disable
SELinux, I do also like to know how things should work (and be able to write
about them!):

{% highlight console %}
$ sudo mkdir /var/ftp/incoming
$ sudo chown ftp:ftp /var/ftp/incoming

# This allows anonymous users to upload, but not see what is in the directory
$ sudo chmod 750 /var/ftp/incoming

$ sudo chcon -u system_u -t public_content_rw_t /var/ftp/incoming
$ sudo setsebool allow_ftpd_anon_write=1
{% endhighlight %}

## Configure vsftpd

{% highlight console %}
$ sudo vi /etc/vsftpd/vsftpd.conf
{% endhighlight %}
{% highlight text %}
anon_upload_enable=YES
{% endhighlight %}

## Startup

Finally, enable and start vsftpd:

{% highlight console %}
$ sudo chkconfig vsftpd on
$ sudo /etc/init.d/vsftpd start
{% endhighlight %}

And that's it, you should now be able to FTP as anonymous and upload files into `/incoming`.
