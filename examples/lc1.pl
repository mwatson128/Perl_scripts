#!/bin/perl

$INPUT = "<$ARGV[0]";

open INPUT or  die " No input\n";

@input = <INPUT>;

foreach $line (@input) {
  $lc_ln = lc $line;
  print $lc_ln;
}

