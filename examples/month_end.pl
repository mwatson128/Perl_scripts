#!/bin/perl
###########################################################################
# month_end.pl - Script for month end billing for Ultraswitch. 1.8
# (]$[) month_end.pl:1.8 | CDATE=11/29/06 14:44:25 
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

$ENV{PATH} = ".:/$zone/usw/offln/bin:/bin:/usr/bin:/usr/.ucbucb:/usr/local/bin:/usr/ucb:/$zone/usw/reports/monthly/bin:/pdl/bin:/home/uswrpt/teTeX/bin/sparc-solaris2.5/";
$ENV{INFORMIXDIR} = "$zone_informixdir";
$ENV{ONCONFIG} = "onconfig.$zone_informixserver";
$ENV{INFORMIXSERVER} = "${zone_informixserver}";
$REPDIR = "/$zone/usw/reports/monthly";
$BILLDIR = "/$zone/usw/reports/monthly/billing";
$TRANSDIR = "/$zone/usw/reports/monthly/trans";
$TEXDIR = "/$zone/usw/reports/monthly/texreports";
$prev_mon = qx(pvmon);
$gds_var = 0;
#Open log file.
$LOG = ">> $REPDIR/log/month$prev_mon.log";
open LOG or die "can't open log file!";
select LOG; $| = 1;          # Have log file print immediately. 

print LOG "$zone  zone \n";
print LOG "$zone_informixserver server \n";
print LOG "$zone_informixdir dir \n";

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

# Volume by day report
qx(volday -m > $REPDIR/volume/all$prev_mon.vbd);

# ALL|ALL
qx(billing -m > $BILLDIR/all$prev_mon.bil);
qx(billing -m -o latex > $TEXDIR/billing/all$prev_mon.bil);
qx(trans -m > $TRANSDIR/all$prev_mon.mon);
qx(trans -m -o latex > $TEXDIR/trans/all$prev_mon.mon);

# Read in the file.
$CHAINFILE = "< $REPDIR/chains.cfg";
open CHAINFILE or die "$0 can't open configuration file.";

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

  # Save the primary ID for file naming.
  @f_elem = split /\|/, $all_hrs[0];
  $hrs_prime = lc $f_elem[0];
  chomp $hrs_prime;

  # Save some effort by not doing this for chains of one.
  if ($num_hrs > 1) {
    $hrs_list = join '|', @all_hrs;  
  }
  else {
    $hrs_list = $all_hrs[0];
  }

  #Produce billing for the HRS and subs.
  qx(billing -m -h "$hrs_list" > $BILLDIR/hrs/$hrs_prime$prev_mon.bil);
  qx(billing -m -o latex -h "$hrs_list" > $TEXDIR/billing/hrs/$hrs_prime$prev_mon.bil);

  #Produce transactions for HRS and subs.
  qx(trans -m -h "$hrs_list" > $TRANSDIR/hrs/$hrs_prime$prev_mon.mon);
  qx(trans -m -o latex -h "$hrs_list" > $TEXDIR/trans/hrs/$hrs_prime$prev_mon.mon);

  foreach $gds (@gds_list) {

    # find the lower case gds for filenaming.
    ($char1, $char2) = split //,$gds;
    $char1 .= $char2;
    $lc_gds = lc $char1;

    qx(billing -m -h "$hrs_list" -a "$gds" > $BILLDIR/hrsgds/$lc_gds$hrs_prime$prev_mon.bil);
    qx(trans -m -h "$hrs_list" -a "$gds" > $TRANSDIR/hrsgds/$lc_gds$hrs_prime$prev_mon.mon);
    $all_gds{$gds} = $gds;
  }

  # If there are no subs, this can be skipped.
  if ($num_hrs > 1) {

    foreach $hrs (@all_hrs) {
    
      # Find the lower case of HRS sub.
      @f_elem = split /\|/, $hrs;
      $lc_hrs = lc $f_elem[0];
      chomp $lc_hrs;

      # Collect billing for subchains
      qx(billing -m -h "$hrs" > $BILLDIR/hrs2/$lc_hrs$prev_mon.bil); 
      #qx(billing -m -o latex -h "$hrs" > $TEXDIR/billing/hrs2/$lc_hrs$prev_mon.bil); 
      qx(trans -m -h "$hrs" > $TRANSDIR/hrs2/$lc_hrs$prev_mon.mon); 
      #qx(trans -m -o latex -h "$hrs" > $TEXDIR/trans/hrs2/$lc_hrs$prev_mon.mon); 
    
      foreach $gds (@gds_list) {

        # find the lower case gds for filenaming.
        ($char1, $char2) = split //,$gds;
        $char1 .= $char2;
        $lc_gds = lc $char1;
  
        qx(billing -m -h "$hrs" -a "$gds" > $BILLDIR/hrs2gds/$lc_gds$lc_hrs$prev_mon.bil);
        qx(trans -m -h "$hrs" -a "$gds" > $TRANSDIR/hrs2gds/$lc_gds$lc_hrs$prev_mon.mon);
      }
    }
  }
}

close(CHAINFILE);

foreach $gds (values %all_gds) {
   
  # find the lower case gds for filenaming.
  ($char1, $char2) = split //,$gds;
  $char1 .= $char2;
  $lc_gds = lc $char1;

  # Now do billing and transactions for individual GDS's.
  qx(billing -m -a "$gds" > $BILLDIR/gds/$lc_gds$prev_mon.bil);
  qx(trans -m -a "$gds" > $TRANSDIR/gds/$lc_gds$prev_mon.mon);

}

print LOG "$0: Finished at ", `date`; 
close(LOG);

