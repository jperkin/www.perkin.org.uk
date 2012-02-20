---
layout: post
title: Graphing memory usage during an MTR run
tags: [mtr, mysql]
---

In order to optimally size the amount of RAM to allocate to a set of new
machines for running MTR, I ran a few tests to check the memory usage of an MTR
run for mysql-trunk and cluster-7.1.  As using a RAM disk considerably speeds
things up, I set the vardir to be on `/ramdisk` and logged the usage of that
too.

The tests were performed on an 8-core E5450 @ 3.00GHz with 24GB RAM, with 8GB
allocated to `/ramdisk`.  Each branch ran the `default.daily` collection, which
generally contains the most testing we do per-run.  Between each run I rebooted
the machine to clear the buffer cache and `/ramdisk`.

I used something like the script below, which saved the per-second usage of
`/ramdisk`, the total RAM used, and the RAM used minus buffers.

{% highlight bash %}
#!/bin/bash

BRANCH="mysql-trunk"
BUILDDIR="mysql-5.6.3-m5-linux2.6-x86_64"
TESTDIR="${HOME}/mtr-test/${BRANCH}"

stats()
{
  i=1
  rm -f ${TESTDIR}/stats-${BRANCH}
  while [ -f ${TESTDIR}/running ]; do
    rd=$(df -k /ramdisk | awk '/^\// {print $3}')
    mem=$(free | awk '/^Mem/ {print $3}')
    mem1=$(free | awk '/cache:/ {print $3}')
    echo "${i} ${rd} ${mem} ${mem1}" >>${TESTDIR}/stats-${BRANCH}
    i=$((i+1))
    sleep 1
  done
}

export TMPDIR="${TESTDIR}/tmp"
rm -rf ${TMPDIR}
mkdir -p ${TMPDIR}

>${TESTDIR}/running
stats &

(
  cd ${TESTDIR}/${BUILDDIR}/mysql-test

  perl mysql-test-run.pl ... --parallel=8 --vardir=/ramdisk/mtr-${BRANCH}/...
  mv /ramdisk/mtr-${BRANCH}/* ${TMPDIR}/
  ...
)

sync
rm -f ${TESTDIR}/running
wait
{% endhighlight %}

First I graphed a straight run of the two branches, using the following gnuplot script:

{% highlight gnuplot %}
set terminal png enhanced font "Times,11" size 640,768
set output "mtr-ram.png"
set title "MTR memory usage (8-core Xeon, 24GB, 8GB RAM disk)"
set xlabel "Time (minutes)"
set ylabel "Memory usage (GB)"
set yrange [0:16]
set xtics 10
set key top box
set grid
plot "stats-mysql-trunk" every 60 using (($1)/60):(($2)/1024/1024) \
        title 'mysql-trunk /ramdisk usage' with lines, \
     "stats-mysql-trunk" every 60 using (($1)/60):(($3)/1024/1024) \
        title 'mysql-trunk RAM (inc buf)' with lines, \
     "stats-mysql-trunk" every 60 using (($1)/60):(($4)/1024/1024) \
        title 'mysql-trunk RAM (exc buf)' with lines, \
     "stats-mysql-cluster-7.1" every 60 using (($1)/60):(($2)/1024/1024) \
        title 'cluster-7.1 /ramdisk usage' with lines, \
     "stats-mysql-cluster-7.1" every 60 using (($1)/60):(($3)/1024/1024) \
        title 'cluster-7.1 RAM (inc buf)' with lines, \
     "stats-mysql-cluster-7.1" every 60 using (($1)/60):(($4)/1024/1024) \
        title 'cluster-7.1 RAM (exc buf)' with lines
{% endhighlight %}

![MTR memory usage](/files/images/mtr-ram.png)

I then performed a valgrind run on mysql-trunk using similar scripts.  As
valgrind takes considerably longer (and uses more RAM) I kept it separate as
the combined graph isn't very clear:

![MTR+valgrind memory usage](/files/images/mtr-ram-valgrind.png)

So, based on these results, the host machine (16GB RAM + 8GB RAM disk) is
probably a sensible guide for now, and allows for some future growth.
