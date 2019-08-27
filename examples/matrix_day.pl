#!/bin/perl
#
# Script to run daily billing and glean specific totals.
#
# (]$[) daybill.pl:1.7 | CDATE=06/05/02 12:30:39

use Getopt::Std;

getopts('m:');

$ARGC = @ARGV;

if ($ARGC >= 1) {
  print "Usage: $0 -m MM/DD/YY\n";
  print "   All other command line arguments get this message.\n";
  exit;
}

printf "Billing for $opt_m\n";
printf "chain,Status Mods,AA,UA|1V|1C|1G,1P,1A,WB,MS,HD,TOTAL\n";

@target = qx(/usr/bin/ls /usw/reports/daily/billing/data/*.bil);

if ($opt_m) {
  @day = split /\//, $opt_m;
}


foreach $file (@target) {

  chomp $file;
 # print $file, "  =";

  @info = qx(grep $day[0]\/$day[1]\/$day[2] $file);
    
  chomp $info[0];
  @part = split /:| +/, $info[0];

  @tmp = split /\//, $file;
  @chain = split /\./, $tmp[6];
  $hrs = uc $chain[0];

  if ($hrs eq "ALL") {
    $all_bil = sprintf "%s,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
               "Total", $part[3], $part[5], $part[6], $part[7],
	       $part[8],$part[9],$part[10], $part[11], $part[4];
  }
  else {
    printf "%s,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
           $hrs, $part[3], $part[5], $part[6], $part[7],
           $part[8],$part[9],$part[10], $part[11], $part[4];
  }

}

print $all_bil;

 

