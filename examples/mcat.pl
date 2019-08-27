#!/bin/perl

foreach $fle (@ARGV) {

  print "===>  $fle  <===\n";
  $rc = qx(/bin/cat $fle);
  print $rc;
}

print "\n";
