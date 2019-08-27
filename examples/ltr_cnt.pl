#!/bin/perl

$ifp = $ARGV[0];
open IFP, $ifp or die "can't open file!\n";

while (<IFP>) {

  chomp;
  @letters = split //, $_;
  foreach $l (@letters) {
    $group_l{$l} += 1;
  }

}

$cnt = 1;
print "Letter: \# in file\n";
print '=' x 60, "\n";
foreach $key (sort keys %group_l) {
  print "\"$key\" : ";
  printf "%4d ", $group_l{$key};
  if (0 == ($cnt % 4)) {
    print "\n";
  }else {
    print "\t";
  }
  $cnt++;
}

print "\n";

