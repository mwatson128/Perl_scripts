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

$DATAFILE = "</usw/reports/daily/billing/maillist.cfg";
#$DATAFILE = "</usw/reports/daily/billing/chn.cfg";
open DATAFILE or die "No config file found: $DATAFILE\n";

while (<DATAFILE>) {
  chomp $_;
  # initialize MAILLIST for new username.
  if ( $_ =~ /^#/ || $_ =~ /^$/ ) {
    # Please skip the comments and blank lines.
    next;
  }
  else {
    @info  = split /\|/,$_;
    $config_file{$info[1]} = $_;

  }
}
close DATAFILE;

foreach $name ( sort( keys %config_file )) {

  @user = split /\|/, $config_file{$name};
 
  $MAILFILE = ">tmp.$name";
  open MAILFILE or die "Can't open output file: $MAILFILE";
  print MAILFILE "\t\t\t\tDaily billing summary for ", $user[0], "\n\n";

  for ($i = 2; $i <= $#user; $i++) {
    print MAILFILE "                  Daily Booking Activity for ", 
                   $user[$i],  "\n\n";
    print MAILFILE "            Status     Net ", "\n";
    printf MAILFILE "             Segs    Bookings %7s%7s%7s%7s%7s%7s\n", 
                   "AA", "UA", "1P", "1A", "WB", "MS";
    $chn_file = qx(tail -14 /usw/reports/daily/billing/data/$user[$i].bil);
    print MAILFILE $chn_file, "\n\n";
  }
  close MAILFILE;

  qx(cat tmp.$name | mailx -s "$user[0] Daily Billing" $user[1]\@pegs.com);
  qx(rm tmp.$name);

}

