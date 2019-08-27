#!/usr/bin/perl

$ARGC = @ARGV;
if ($ARGC == 4) {
  $chain=$ARGV[0];
  $brand=$ARGV[1];
  $oldchain=$ARGV[2];
  $oldbrand=$ARGV[3];
}
else {
  print "usage: convert.pl newchain newbrand oldchain oldbrand \n";
  exit 0;
}

@files = `ls -1`;

foreach $file (@files) {
  chomp $file;
  print $file, "\n";

  $lc_nc = lc $chain;
  $lc_nb = lc $brand;
  $lc_oc = lc $oldchain;
  $lc_ob = lc $oldbrand;

  `sed s/$oldchain/$newchain/g $file > hold`;
  `mv hold $file`;

  `sed s/$oldbrand/$brand/g $file > hold`;
  `mv hold $file`;

  `sed s/$lc_oc/$lc_nc/g $file > hold`;
  `mv hold $file`;

  `sed s/$lc_ob/$lc_nb/g $file > hold`;
  `mv hold $file`;

}
