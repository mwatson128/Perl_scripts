#!/bin/perl
#
# find the HD/DM bookings and gather their:
# Brand|usw PID|CNF|CNX|
#
#0  |1  |2           | 3 |    4    |   5   |   6    | 7 | 8 |    9     | 10
#HRS|GDS|Traffic type|PDM|Direction|USW MSN|ACT code|BKS|IND|Num nights|Num
#     |  11  |   12    | 13| 14   |   15      |  16     |
#Rooms|Propid|Room Type|CNF|SEGNUM|Status Code|Cancelnum|
#
# (]$[) dm_find.pl:1.3 | CDATE=10/07/08 12:23:37

$zone = `uname -n`;
chomp $zone;

$DATE = $ARGV[0];
$fdate = `/uswsup01/usw/offln/bin/getydate -o sig`;
$fileday = "/uswsup01/usw/offln/daily/$fdate.billing";
$finished = 0;
$maxtry = 0;


# Mechinism added to check if prod ops has finished. Check the file
# /uswsup01/usw/offln/daily/$fdate.billing if it doesn't exist, then billing
# hasn't competed, wait 30 minutes and try again.
while (!$finished && $maxtry <= 8 ) {
  if ( -f $fileday ) {
    # The file from the days billing is present,
    # billing has finished.
    $finished = 1;
  }
  else {
    # The file does not exist.  Billing from the day before hasn't 
    # finished.  Wait for it, and quit after 4 hours.
    if ($maxtry < 8) {
      $maxtry++;
      sleep(1800);
    }
    else {
      exit;
    }
  }
}

$OFP = ">/tmp/hd_${DATE}.unl";
$IFP = "</tmp/hd_${DATE}.sum";

qx(gzcat /$zone/usw/reports/daily/sum/rpt${DATE}.sum | grep "^..|HD|" > /tmp/hd_${DATE}.sum);

open IFP or die " can't open in file\n";
open OFP or die " can't open out file\n";

while (<IFP>) {

  chomp;
  @ln = split /\|/;

    
  if ($ln[13] || $ln[16]) {
    printf OFP "%s|%s|%s|%s|%s|\n", $ln[0], $ln[11], $ln[13], $ln[16], 
  }

}

close IFP;
close OFP;

qx(mv /tmp/hd_${DATE}.unl  /$zone/loghist/billupdate/);
qx(rm -f /tmp/hd_${DATE}.sum);


