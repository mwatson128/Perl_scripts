#!/bin/perl
use POSIX;

open(IN, "</home/bfausey/BatchIn.log.2013-06-30") or die "Couldn't open file for processing: $!";

while(<IN>) {
  if ($_ =~ /PrimaryLangID=(....)/) {
     print "$1\n" if ($1 ne "\"en\""); 
  }
  if ($_ =~ /UniqueID ID=(.*) Type/) {
     print "$1\n";
  }
}

close(IN);
exit;
