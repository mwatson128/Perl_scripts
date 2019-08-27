#!/bin/perl

$IFP = "<${ARGV[0]}";

open IFP or die " can't open input!\n";

while (<IFP>) {
  chomp;

  $line = $_;

  $ifp_hash{$line} = $line;

}
close IFP;

foreach $ln ( sort keys %ifp_hash) {
  print "${ln}\n";
}

