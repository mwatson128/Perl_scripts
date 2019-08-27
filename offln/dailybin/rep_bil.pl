#!/bin/perl
#
# Script to run daily billing and glean specific totals.
#

#import environment.
$ENV{PATH} = "/usw/offln/bin:/bin:/usr/bin:/usr/.ucbucb:/usr/local/bin:/usr/ucb:/usw/reports/monthly/bin:/pdl/bin:/home/uswrpt/teTeX/bin/sparc-solaris2.5/";
$ENV{CWD} = "/usr/reports/daily/billing";
$ENV{TZ} = "GMT+24";
$ENV{INFORMIXDIR} = "/informix";
$ENV{ONCONFIG} = "onconfig.ped_test";
$ENV{INFORMIXSERVER} = "ped_test_shm";

$ARGC = @ARGV;
if ( $ARGC < 1) {

  $DATE = `/usw/offln/bin/getydate -s`;
  @o_date = split /\//, $DATE;
  $fdate = `/usw/offln/bin/getydate -o sig`;
  chomp ($arg_date = `date`);
  ($day, $mon, $mday, $hour, $tz, $year) = split /\s/,$arg_date;
  $tot_day = "$DATE    $day";

  # Mechinism added to check if prod ops has finished. Check the file
  # /usw/offln/daily/$fdate.billing if it doesn't exist, then billing
  # hasn't competed, wait 15 minutes and try again.
  $fileday = "/usw/offln/daily/$fdate.billing";
  $finished = 0;
  $maxtry = 0;
  while (!$finished && $maxtry <= 8 ) {
    if ( -f $fileday ) {
      # The file from the days billing is present,
      # billing has finished.
      $finished = 1;
    }
    else {
      # The file does not exist.  Billing from the day
      # before hasn't finished.  Wait for it, and quit after 2 hours.
      if ($maxtry < 8) {
        $maxtry++;
      }
      else {
        exit;
      }
      sleep(900);
    }
  }
}
elsif ( $ARGC == 1 && $ARGV[0] =~ /(\d+)/ ) {

  print "Usage: rep_bil.pl [DATE Day]\n";
  print "   DATE = Date to run reports for in mm/dd/yy format.\n";
  print "   Day = 3 letter day of the Week ie Mon.\n";
  print "   All other command line arguments get this message.\n";
  print "Generate daily billing and append to existing file.\n";
  print "Configuration is in rep_list.cfg.\n";
  exit;
}
elsif ( $ARGC == 2) {

  chomp ($DATE = $ARGV[0]);
  @o_date = split /\//, $DATE;

  $day = $ARGV[1];
  $tot_day = "$DATE    $day";
  
}
else {

  print "Usage: rep_bil.pl [DATE Day]\n";
  print "   DATE = Date to run reports for. in mm/dd/yy format.\n";
  print "   Day = 3 letter day of the Week ie Mon.\n";
  print "   All other command line arguments get this message.\n";
  print "Generate daily billing and append to existing file.\n";
  print "Configuration is in maillist.cfg.\n";
  exit;
}

#$DATAFILE = "</usw/reports/daily/billing/rep_list.cfg";
$DATAFILE = "</home/mikew/reports/rep_bil/rep_list.cfg";
@gds_list = ("AA|UA|1V|1C|1G|1P|1A", "WB|MS");

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

  # Save the primary ID for file naming.
  @f_elem = split /\|/, $chain;
  $hrs_prime = lc $f_elem[0];
  chomp $hrs_prime;

  #form the file date string
  $out_d = $o_date[0] . $o_date[1];

  # Open the output file for writing.
#  $OUTFILE = ">>/usw/reports/daily/billing/data/$hrs_prime$out_d.bil";
  $OUTFILE = ">>/home/mikew/reports/rep_bil/$hrs_prime$out_d.bil";
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
  $bill_report[45] =~ /(-*\d+)/;
  $bill_all[0] = $1;
  $bill_report[58] =~ /(-*\d+)/;
  $bill_all[1] = $1;  

  if ( $chain eq "ALL") {

    foreach $gds (@gds_list) {

      # Do billing for this chain and GDS only.
      @bill_report = `billing -t $DATE -a $gds`;

      # search lines 44 & 57 for numbers and save
      # what you find by GDS.
      $bill_report[45] =~ /(-*\d+)/;
      $bill_hash{$gds}[0] = $1;
      $bill_report[58] =~ /(-*\d+)/;
      $bill_hash{$gds}[1] = $1;

    }
  }
  else {

    foreach $gds (@gds_list) {

      # Do billing for this chain and GDS only.
      @bill_report = `billing -t $DATE -h "$chain" -a $gds`;

      # search lines 44 & 57 for numbers and save
      # what you find by GDS.
      $bill_report[45] =~ /(-*\d+)/;
      $bill_hash{$gds}[0] = $1;
      $bill_report[58] =~ /(-*\d+)/;
      $bill_hash{$gds}[1] = $1;

    }
  }
  
  printf OUTFILE "%s    %6d   ", $tot_day, $bill_all[0];
  foreach $gds (@gds_list) {
    printf OUTFILE "%12d", $bill_hash{$gds}[0];
  }
  print OUTFILE "\n";
  close OUTFILE;
}

#foreach $name ( sort( keys %config_file )) {
#
#  @user = split /\:/, $config_file{$name};
# 
#  $MAILFILE = ">tmp.$name";
#  open MAILFILE or die "Can't open output file: $MAILFILE";
#  print MAILFILE "            $DATE Daily billing summary for ", $user[0], "\n\n";
#
#  for ($i = 2; $i <= $#user; $i++) {
#    print MAILFILE "               Daily Booking Activity for ", 
#                   $user[$i],  "\n\n";
#    print MAILFILE "               Status     Net ", "\n";
#    printf MAILFILE "                Segs    Bookings %7s%7s%7s%7s%7s%7s\n", 
#                   "AA", "UA", "1P", "1A", "WB", "MS";
#    $chn_file = qx(tail -14 /usw/reports/daily/billing/data/"$user[$i]".bil);
#    print MAILFILE $chn_file, "\n\n";
#  }
#  close MAILFILE;
#
#  qx(cat tmp.$name | mailx -s "$user[0] Daily Billing for $DATE" $name\@pegs.com);
#  qx(rm tmp.$name);

#}

