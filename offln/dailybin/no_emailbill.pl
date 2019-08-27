#!/bin/perl
#
# Script to run daily billing and glean specific totals.
#
# (]$[) %M%:%I% | CDATE=%G% %U%

#import environment.
$ENV{PATH} = "/usw/offln/bin:/bin:/usr/bin:/usr/.ucbucb:/usr/local/bin:/usr/ucb:/usw/reports/monthly/bin:/pdl/bin:/home/uswrpt/teTeX/bin/sparc-solaris2.5/";
$ENV{CWD} = "/usr/reports/daily/billing";
$ENV{TZ} = "GMT+24";
$ENV{INFORMIXDIR} = "/informix";
$ENV{ONCONFIG} = "onconfig.ped_test";
$ENV{INFORMIXSERVER} = "ped_test_shm";


$ARGC = @ARGV;
if ( $ARGC < 1) {

  chomp ($DATE = `/usw/offln/bin/getydate -s`);
  chomp ($arg_date = `date`);
  ($day, $mon, $mday, $hour, $tz, $year) = split /\s/,$arg_date;
  $tot_day = "$day: $DATE";
}
elsif ( $ARGC == 1 && $ARGV[0] =~ /(\d+)/ ) {

  print "Usage: daybill.pl [DATE Day]\n";
  print "   DATE = Date to run reports for. in mm/dd/yy format.\n";
  print "   Day = 3 letter day of the Week ie Mon.\n";
  print "   All other command line arguments get this message.\n";
  print "Generate daily billing and append to existing file.\n";
  print "Configuration is in maillist.cfg.\n";
  exit;
}
elsif ( $ARGC == 2) {

  chomp ($DATE = $ARGV[0]);

  $day = $ARGV[1];
  $tot_day = "$day: $DATE";
  
}
else {

  print "Usage: daybill.pl [DATE Day]\n";
  print "   DATE = Date to run reports for. in mm/dd/yy format.\n";
  print "   Day = 3 letter day of the Week ie Mon.\n";
  print "   All other command line arguments get this message.\n";
  print "Generate daily billing and append to existing file.\n";
  print "Configuration is in maillist.cfg.\n";
  exit;
}

$DATAFILE = "</usw/reports/daily/billing/maillist.cfg";
#$DATAFILE = "</usw/reports/daily/billing/chn.cfg";  # for testing purposes
@gds_list = ("AA", "\"UA|1V|1C|1G\"", "1P", "1A", "WB", "MS");

# Read in chains that we need to run billing for. 
open DATAFILE or die "No config file found: $DATAFILE\n";

while (<DATAFILE>) {

  # Please skip blank lines and comments.
  next if /^#|^$/;

  chomp;

  @info  = split /\:/,$_;
  $config_file{$info[1]} = $_;

  for( $i = 2; $i <= $#info; $i++) {
    # Put the chains in a hash, so we get only unique ones.
    $chain_codes{$info[$i]} = $info[$i]; 
  }
 
}
close DATAFILE;

foreach $chain ( sort (keys %chain_codes)) {

  # Need to get newline out of chain.
  chomp($chain);

  # Open the output file for writing.
  $OUTFILE = ">>/usw/reports/daily/billing/data/$chain.bil";
  open OUTFILE or die "Can't open outfile.";

  if ( $chain eq "ALL") {
    # Do billing for all chains 
    @bill_report = `billing -t $DATE`;
  }
  else {
    # Do billing for this chain 
    @bill_report = `billing -t $DATE -h "$chain"`;
  }

  # these are the lines from the billing that we need.
  # so grab the numbers from lines 44 and 57.
  $bill_report[44] =~ /(-*\d+)/;
  $bill_all[0] = $1;
  $bill_report[57] =~ /(-*\d+)/;
  $bill_all[1] = $1;  

  if ( $chain eq "ALL") {

    foreach $gds (@gds_list) {

      # Do billing the this chain and GDS only.
      @bill_report = `billing -t $DATE -a $gds`;

      # search lines 44 & 57 for numbers and save
      # what you find by GDS.
      $bill_report[44] =~ /(-*\d+)/;
      $bill_hash{$gds}[0] = $1;
      $bill_report[57] =~ /(-*\d+)/;
      $bill_hash{$gds}[1] = $1;

    }
  }
  else {

    foreach $gds (@gds_list) {

      # Do billing the this chain and GDS only.
      @bill_report = `billing -t $DATE -h "$chain" -a $gds`;

      # search lines 44 & 57 for numbers and save
      # what you find by GDS.
      $bill_report[44] =~ /(-*\d+)/;
      $bill_hash{$gds}[0] = $1;
      $bill_report[57] =~ /(-*\d+)/;
      $bill_hash{$gds}[1] = $1;

    }
  }
  
  printf OUTFILE "%s %7d   %6d   ", $tot_day, $bill_all[1], $bill_all[0];
  foreach $gds (@gds_list) {
    printf OUTFILE "%7d", $bill_hash{$gds}[0];
  }
  print OUTFILE "\n";
  close OUTFILE;
}


