#!/bin/perl

if (!$ARGV[0]) {
  $date = `date '+%m%d%y'`;
}
else {
  $date = $ARGV[0];
}
chomp $date;

$ifp = "/loghist/ub/per" . $date . "UB.sum";

open IFP, $ifp or die "Can't open infile $ifp!\n";

while (<IFP>) {
  
  chomp;
  @info = split /\|/;

  $info[5] =~ s/BA/00/;

  # Convert from MilliSec to 10th Sec
  ## 10/24/03 Bert changed his program to do this.
  ##$info[17] = int $info[17] * .01;
  ##$info[18] = int $info[18] * .01;

#  for ($i = 0; $i < $#info; $i++) {
  for ($i = 0; $i < 19; $i++) {
    if ($i != 2) {
      print $info[$i], "\|";
    }
  }
  printf "\n";

}
