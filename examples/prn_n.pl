#!/bin/perl

foreach $num (1..10) {
  foreach $sub (1..9) {
    print "$sub";
  }
  print "\033[01;34m$num\033[0m";
}

print "\n";
