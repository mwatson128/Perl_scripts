#!/bin/perl
######################################################################
# month_latex.pl UltraSwitch Latex formating script
# (]$[) month_latex.pl:1.1 | CDATE=10/24/00 11:53:35
######################################################################
#
# month_latex.pl outputs the monthly billing and trans reports in Latex format
#  for printing and mailling to customers.
#
######################################################################

$ENV{PATH} = ".:/usw/offln/bin:/bin:/usr/bin:/usr/.ucbucb:/usr/local/bin:/usr/ucb:/usw/reports/monthly/bin:/pdl/bin:/home/uswrpt/teTeX/bin/sparc-solaris2.5/";
$ENV{INFORMIXDIR} = "/informix";
$ENV{ONCONFIG} = "onconfig.ped_test";
$ENV{INFORMIXSERVER} = "ped_test_shm";
$REPDIR = "/usw/reports/monthly";
$BILLDIR = "/usw/reports/monthly/billing";
$TRANSDIR = "/usw/reports/monthly/trans";
$TEXDIR = "/usw/reports/monthly/texreports";
$prev_mon = qx(pvmon);
$gds_var = 0;

#Open log file.
$LOG = ">> $REPDIR/log/month$prev_mon.log";
open LOG or die "can't open log file!";
select LOG; $| = 1;          # makes prints output immediately.

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

# Read in the file.
$CHAINFILE = "< $REPDIR/latex.cfg";
open CHAINFILE or die "$0 can't open configuration file.";
print LOG "$0 Processing HRS: ";

while (<CHAINFILE>) {
  
  # Please skip the comments and blank lines.
  next if /^#|^$/;

  # get rid of newline.
  chomp;
  
  if (/GDS/) {
    @info  = split /GDS/,$_;
    @all_hrs = split /\s/,$info[0];
    $num_hrs = @all_hrs;
    @gds_list = split /\s/,$info[1];
    # Get rid of the space in front of GDS's.
    shift @gds_list;
    $num_gds = @gds_list; 
    if ($num_gds == 0) {
      $GDS_present = 0;
    }
    else {
      $GDS_present = 1;
    }
  }
  else {
    @all_hrs = split /\s/;
    $num_hrs = @all_hrs;
    $GDS_present = 0;
  }

  # Save some effort by not doing this for chains of one.
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

  print LOG "$hrs_prime ";

  #Produce latex billing for the primary HRS.
  qx(billing -m -o latex -h "$hrs_list" > $TEXDIR/billing/hrs/$hrs_prime$prev_mon.bil);

  #Produce latex transactions for primary HRS.
  qx(trans -m -o latex -h "$hrs_list" > $TEXDIR/trans/hrs/$hrs_prime$prev_mon.mon);

  if ($GDS_present) {
    
    foreach $gds (@gds_list) {

      # find the lower case gds for filenaming.
      ($char1, $char2) = split //,$gds;
      $char1 .= $char2;
      $lc_gds = lc $char1;

      qx(billing -m -o latex -h "$hrs_list" -a "$gds" > $TEXDIR/billing/hrsgds/$lc_gds$hrs_prime$prev_mon.bil);
      qx(trans -m -o latex -h "$hrs_list" -a "$gds" > $TEXDIR/trans/hrsgds/$lc_gds$hrs_prime$prev_mon.mon);
      $all_gds{$gds} = $gds;
    }
  }

  # If there are no subs, this can be skipped.
  if ($num_hrs > 1) {

    foreach $hrs (@all_hrs) {

      # Find the lower case of HRS sub.
      ($char1, $char2) = split / */, $hrs;
      $char1 .= $char2;
      $lc_hrs = lc $char1;

      # Collect billing for subchains
      qx(billing -m -o latex -h "$hrs" > $TEXDIR/billing/hrs2/$lc_hrs$prev_mon.bil);
      qx(trans -m -o latex -h "$hrs" > $TEXDIR/trans/hrs2/$lc_hrs$prev_mon.mon);
    
      if ($GDS_present) {

        foreach $gds (@gds_list) {

          # find the lower case gds for filenaming.
          ($char1, $char2) = split //,$gds;
          $char1 .= $char2;
          $lc_gds = lc $char1;

          qx(billing -m -o latex -h "$hrs" -a "$gds" > $TEXDIR/billing/hrs2gds/$lc_gds$lc_hrs$prev_mon.bil);
          qx(trans -m -o latex -h "$hrs" -a "$gds" > $TEXDIR/trans/hrs2gds/$lc_gds$lc_hrs$prev_mon.mon);
        }
      }
    } 
  }
}

qx(billing -m -o latex -a MS > $TEXDIR/billing/gds/ms$prev_mon.bil);
close (CHAINFILE);

print LOG "\n$0: Ended at ", `date`, "\n";
close (LOG);

