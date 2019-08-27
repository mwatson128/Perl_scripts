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
#0 |1 |2|3|4|     5        |6 |   7    |    8  |9|10| 11  |  12  |    13    |14 
#HH|HD|A| |u|140342CB1F0F1F|SS|07591640|12JUL05|3|1 |04769|A03BK7|3211182954|1 
#|15|16|
#|HK|  |1120608015|1120608015|1120608015|1120608015|1120608015
#
# (]$[) dm_find.pl:1.1 | CDATE=12/04/06 13:50:22

$zone = `uname -n`;
chomp $zone;

$DATE = $ARGV[0];

qx(gzcat /$zone/usw/reports/daily/sum/rpt${DATE}.sum | grep "^..|HD|" > /tmp/hd_${DATE}.sum);


$OFP = ">/$zone/loghist/billupdate/hd_${DATE}.unl";
$IFP = "</tmp/hd_${DATE}.sum";

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

qx(rm -f /tmp/hd_${DATE}.sum);


