#!/bin/perl
#
# Script to run daily billing and glean specific totals.
#
# (]$[) daybill.pl:1.7 | CDATE=06/05/02 12:30:39

use Getopt::Std;

#import environment.
$ENV{PATH} = "/usw/offln/bin:/bin:/usr/bin:/usr/.ucbucb:/usr/local/bin:/usr/ucb:/usw/reports/monthly/bin:/pdl/bin:/home/uswrpt/teTeX/bin/sparc-solaris2.5/";
$ENV{TZ} = "GMT+24";
$ENV{INFORMIXDIR} = "/informix";
$ENV{ONCONFIG} = "onconfig.ped_test";
$ENV{INFORMIXSERVER} = "ped_test_shm";

# Number of days in each month
%year_day_num = (
  0 => 31, 1 => 28, 2 => 31, 3 => 30, 4 => 31, 5 => 30,
  6 => 31, 7 => 31, 8 => 30, 9 => 31, 10 => 30, 11 => 31
);


getopts('md');

$ARGC = @ARGV;

if ($ARGC < 1) {
  print "Usage: $0 -m|d CHN date [date ...] \n";
  print "   -m|d = run for month or day granulatity.\n";
  print "   CHN = valid USW chain code or list of chains.\n";
  print "   date = date to run billing for.\n";
  print "   All other command line arguments get this message.\n";
  exit;
}
else {

  $chain = $ARGV[0];
  for ($i = 1, $j = 0; $i < $ARGC; $i++, $j++) {
    $day_s[$j] = $ARGV[$i];
  }
}

@gds_list = ("AA", "\"UA|1V|1C|1G\"", "1P", "1A", "WB", "MS", "HD");
chomp($chain);
$chain = uc $chain;

printf "Billing for chain $chain\n";
printf "DATE,ALL,AA,UA|1V|1C|1G,1P,1A,WB,MS,HD\n";

foreach $d (@day_s) {

  # Reinitialize the billcnt variable.
  $billcnt = 0;

  if ($opt_m) {
    @m = split //, $d;
    $mn = $m[0] . $m[1];
    $yr = $m[6] . $m[7];
    $dy = $year_day_num{$mn - 1};
    $od = sprintf("%s/%s/%s", $mn,$dy,$yr);

    # Do billing for this chain for one month 
    @bill_report = `billing -t $d -u $od -h \"$chain\"`;

  }
  else {
 
    $od = FALSE;
    # Do billing for this chain for one day
    @bill_report = `billing -t $d -h \"$chain\"`;
  }
    
  # MIKEW

  # these are the lines from the billing that we need.
  # so grab the numbers from lines 45 and 58.
  $bill_report[45] =~ /(-*\d+)/;
  $bill_hash{ALL}[0] = $1;

  foreach $gds (@gds_list) {
    
    # Do billing the this chain and GDS only.
    if ($od) {
      @bill_report = `billing -t $d -u $od -h \"$chain\" -a $gds`;
    }
    else {
      @bill_report = `billing -t $d -h \"$chain\"`;
    }
 
    # search lines 45 & 58 for numbers and save
    # what you find by GDS.
    $bill_report[45] =~ /(-*\d+)/;
    $bill_hash{$gds}[0] = $1;
 
  }


  printf "%s,%d", $d, $bill_hash{ALL}[0];
  foreach $gds (@gds_list) {
    printf ",%d", $bill_hash{$gds}[0];
  }
  printf "\n";
}

 

