#!/bin/perl -w

$ifp = "<ua042104_b2";
open IFP, $ifp or die "";
$skip = 0;

while (<IFP>) {
  chomp;
  if (/Type B msg/) {
    $line = <IFP>;
    chomp $line;
    if (/pdm/ || $line =~ /AVSTAT/) {
      # skip down to the next whole message
      $skip = 1;
    }
    else {
      # print this one out.
      print "$_\n";
      print "$line\n";
      $skip = 0;
    }
  }
  elsif ($skip) {
    next;
  }
  else {
    print "$_ \n";
  } 
}


