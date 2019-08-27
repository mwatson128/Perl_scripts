#!/bin/sh

nums=`ps -u uswrpt | grep do_test | /bin/awk '{print $1}'`
#nums2=`ps -u uswrpt | grep month_pe | /bin/awk '{print $1}'`

kill -9 $nums 

