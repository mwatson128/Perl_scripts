#!/bin/perl
#
# (]$[) preperf.pl:1.5 | CDATE=11/28/06 13:47:38
#
# Input:
#  0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18
# HRS|GDS|SGA|UTT|LGT|MSN|RQT|RPT|NTP|NRW|HPI|GIL|GOL|HIL|HOL|TMO|TRT|HRT|GRT
#
# Output:
#  0   1   2      3   4   5   6   7   8   9  10  11  12  13  14  15  16  17
# HRS|GDS|UTT|"G"LGT|MSN|RQT|RPT|NTP|NRW|HPI|GIL|GOL|HIL|HOL|TMO|TRT|HRT|GRT
#

$zone = `uname -n`;
chomp $zone;
$LOG = ">>/$zone/loghist/history.log";
open LOG or die "can't open log file.\n";


if (!$ARGV[0]) {
  $date = `date '+%m%d%y'`;
}
else {
  $date = $ARGV[0];
}
chomp $date;

printf LOG "\n=================================\n";
printf LOG "Started processing file at %s", `date`;
printf LOG "Date of run: $date\n";

$ifile = "/$zone/loghist/ub/per" . $date . "UB.sum";
$ofile = "/$zone/usw/offln/daily/per" . $date . "UB.sum";

$ifp = "<$ifile";
$ofp = ">$ofile";

printf LOG "the input file: $ifp\n";

$nofile = 0;
open IFP, $ifp or ($nofile = 1);
open OFP, $ofp or die "Can't open infile $ofp!\n";

if ($nofile) {
  qx(touch $ofile);
  printf LOG "Input file not there, put empty output file at %s", `date`;
  printf LOG "=================================\n";
  close IFP;
  close OFP;
  close LOG;
  exit;
}
  
while (<IFP>) {
  
  chomp;
  @info = split /\|/;

  # Convert UB MSN from BA01 to 0001
  $info[5] =~ s/^../00/;

  # Loop through all of the fields.
  for ($i = 0; $i < 19; $i++) {

    # Supress SGA, $info[2]
    next if ($i == 2);

    # Add G to log time to indicate that it is in GMT
    if ($i == 4) {
      print OFP "G", $info[$i], "\|";
    }
    else {
      print OFP $info[$i], "\|";
    }

  }

  printf OFP "\n";

}

printf LOG "Finished processing file at %s", `date`;
printf LOG "=================================\n";
close IFP;
close OFP;
close LOG;

