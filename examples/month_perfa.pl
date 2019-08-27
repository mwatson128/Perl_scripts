#!/bin/perl
###########################################################################
# month_perfa.pl - Script for month end billing for Ultraswitch. 1.6
# (]$[) month_perfa.pl:1.6 | CDATE=11/29/06 14:44:40
###########################################################################
#
# Perl script to automate the data gathering needed to compile Month end
# Ultraswitch billing.
#
###########################################################################
$zone = `uname -n`;
chomp $zone;
$zone_informixserver = $zone . "_1";
$zone_informixdir = "/informix-" . $zone . "_1";

#$ENV{PATH} = ".:/$zone/usw/offln/bin:/bin:/usr/bin:/usr/.ucbucb:/usr/local/bin:/usr/ucb:/$zone/usw/reports/monthly/bin:/pdl/bin:/home/uswrpt/teTeX/bin/sparc-solaris2.5/";
#$ENV{INFORMIXDIR} = "$zone_informixdir";
#$ENV{ONCONFIG} = "onconfig.$zone_informixserver";
#$ENV{INFORMIXSERVER} = "${zone_informixserver}";
#$ENV{INFORMIXSQLHOSTS} = "${INFORMIXDIR}/etc/sqlhosts.${INFORMIXSERVER}";

$INFORMIXDIR = $ENV{INFORMIXDIR};
$ONCONFIG = $ENV{ONCONFIG};
$INFORMIXSERVER = $ENV{INFORMIXSERVER};
$INFORMIXSQLHOSTS = $ENV{INFORMIXSQLHOSTS};

$REPDIR = "/$zone/usw/reports/monthly";
$PERFDIR = "/$zone/usw/reports/monthly/perf";
$PERFBDIR = "/$zone/usw/reports/monthly/perfb";
$PERF2DIR = "/$zone/usw/reports/monthly/perf2";
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

# Run the performance reports for ALL
qx(perfa -m > $PERFDIR/all$prev_mon.perf);

# Read in the file.
$CHAINFILE = "< $REPDIR/chains.cfg";
open CHAINFILE or die "$0 can't open configuration file.";
  
print LOG "$0: On Chain: ";

while (<CHAINFILE>) {

  # Please skip the comments and blank lines.
  next if /^#|^$/;

  # get rid of newline.
  chomp;

  @info  = split /GDS/,$_;
  @all_hrs = split /\s/,$info[0];
  $num_hrs = @all_hrs;
  @gds_list = split /\s/,$info[1];

  # Get rid of the space in front of GDS's.
  shift @gds_list;

  # Store the GDS's for later use.
  foreach $gds (@gds_list) {
    $all_gds{$gds} = $gds;
  }

  # Save some effort by not joining chains of one.
  if ($num_hrs > 1) {
    $hrs_list = join '|', @all_hrs;
  }
  else {
    $hrs_list = $all_hrs[0];
  }

  # Save the primary ID for file naming.
  ($char1, $char2) = split / */, $all_hrs[0];
  $char1 .= $char2;
  $hrs_prime = lc $char1;

  # Log which chain we're running.
  print LOG "$char1 "; 

  # Produce the performance reports
  qx(perfa -m -h "$hrs_list" > $PERFDIR/$hrs_prime$prev_mon.perf);
  
}

print LOG "\n";

close (CHAINFILE);

foreach $gds (values %all_gds) {

  # find the lower case gds for filenaming.
  ($char1, $char2) = split //,$gds;
  $char1 .= $char2;
  $lc_gds = lc $char1;

  # Produce the performance reports for GDS's.
  qx(perfa -m -a "$gds" > $PERFDIR/gds/$lc_gds$prev_mon.perf);

}

qx(perfa -m -a "MS" > $PERFDIR/ms$prev_mon.perf);

print LOG "$0: Finished at ", `date`;
close(LOG);
