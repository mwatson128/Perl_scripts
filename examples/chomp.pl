#!/bin/perl

$MASTER = "< $ARGV[0]";
open MASTER or die "Can't open MASTER.\n";

while (<MASTER>) {
  chomp;
  chop;
  print $_, "\n";
}

close MASTER;
