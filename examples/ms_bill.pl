#!/bin/perl
###########################################################################
# ms_bill.pl - Script for month end billing for Ultraswitch. 1.3
# (]$[) ms_bill.pl:1.3 | CDATE=12/15/00 09:15:26
###########################################################################
#
# Perl script to automate the data gathering needed to compile Month end
# Ultraswitch billing.
#
###########################################################################

$ENV{PATH} = ".:/usw/offln/bin:/bin:/usr/bin:/usr/.ucbucb:/usr/local/bin:/usr/ucb:/usw/reports/monthly/bin:/pdl/bin:/home/uswrpt/teTeX/bin/sparc-solaris2.5/";
$ENV{INFORMIXDIR} = "/informix";
$ENV{ONCONFIG} = "onconfig.ped_test";
$ENV{INFORMIXSERVER} = "ped_test_shm";
$REPDIR = "/usw/reports/monthly";
$BILLDIR = "/usw/reports/monthly/billing";
$TEXDIR = "/usw/reports/monthly/texreports";
$TRANSDIR = "/usw/reports/monthly/trans";
$ENV{CWD} = $REPDIR;
$prev_mon = qx(pvmon);
$gds_var = 0;

#Open log file.
$LOG = ">> $REPDIR/log/month$prev_mon.log";
open LOG or die "can't open log file!";
select LOG; $| = 1;          # makes prints output immediately rather 

print LOG "$0: START\n"; 
print LOG "$0: start time is ", `date`; 

# Ensure that processing of the previous month has completes before continuing
#can_it_run $SCRIPT $PEOPLE
$ret_val = `billnow`;
if ($ret_val) {
  print LOG "$0: All $prev_mon dailies have run, continuing.\n";
}
else {
  print LOG "$0: Cannot run, daily processing of $prev_mon is incomplete.";
  close(LOG);
  qx(mailx -s "$0 halted" mike.watson\@pegs.com < $REPDIR/log/month$prev_mon.log);
  exit 1;
}

# MS|ALL
qx(billing -m -a MS > $BILLDIR/ms/ms$prev_mon.bil);
qx(billing -m -o latex -a MS > $TEXDIR/billing/gds/ms$prev_mon.bil);
qx(trans -m -a MS >  $TRANSDIR/gds/ms$prev_mon.mon);
qx(trans -m -o latex -a MS > $TEXDIR/trans/gds/ms$prev_mon.mon);

# Read in the file.
$CHAINFILE = "< $REPDIR/ms.cfg";
open CHAINFILE or die "$0 can't open configuration file.";

while (<CHAINFILE>) {
  
  # Please skip the comments and blank lines.
  next if /^#|^$/;

  # get rid of newline.
  chomp;

  $chain = $_;
  $lc_chain = lc $chain;

  qx(billing -m -a MS -h $chain > $BILLDIR/ms/ms$lc_chain$prev_mon.bil);
  qx(trans -m -a MS -h $chain > $TRANSDIR/ms/ms$lc_chain$prev_mon.mon);

}

print LOG "$0: END time is ", `date`; 

close (CHAINFILE);
close (LOG);

