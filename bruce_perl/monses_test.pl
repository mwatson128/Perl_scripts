#!/bin/perl
#
# Gather DB stats: 
# Store in human-readable log file.
#
# THIS SCRIPT REQUIRES PERL.
#
# (]$[) monses.pl:1.7 | CDATE=04/29/07 19:16:45
#
# 10/20/2009 - Modified by Fengming Lou for 1). Fixed sleep with negative time 2). Trap QUIT signal to exit
#              3). Removed hourly rotation of Monses process

use FileHandle;
use Getopt::Std;
use POSIX qw(strftime);

# Subs
sub usageexit;
# Get instance from command line
getopts('i');

# Make sure ROOTDIR is valid
&checkMonthRollover();

## Set up variables
$refresh = 30;
$staleReadyQ = 60;
$minWindowSize = 8192;
$winBucketSize = 2048;
$queueBucketSize = 512;
$INF_PORT = 1602;
$SIG{QUIT} = \&QUIT_handler;


# Create output file names
$filedate = `date +%Y%m%d`;
chomp $filedate;

# Build filename to open
$outputFile = sprintf "%s/monses.%s", $ROOTDIR, $filedate;
$outputRawFile = sprintf "%s/monsesRaw.%s", $ROOTDIR, $filedate;
$outputStatsFile = sprintf "%s/monsesStats.%s", $ROOTDIR, $filedate;

# unbuffer STDOUT
STDOUT->autoflush(1);

# open up output file
open (OUT, ">> $outputFile");
open (RAW, ">> $outputRawFile");
OUT->autoflush(1);
RAW->autoflush(1);

########################################
# Loop through iterations              #
########################################
while (1 == 1){
  &checkHourRollover();

  my $sleeptime = 0; 
  $begin = time();

  print OUT '='x60,"\n";
  print OUT `date -u`;

  print RAW '='x60,"\n";
  print RAW `date -u`;

  $cmd_data = "[" . strftime("%Y-%m-%d %T", gmtime($begin)) . "][$zone][monses]";

  # get the data
  $load = `uptime`;
  @vmstat= `vmstat 1 2`;

  # process each sub item

  # Log the statistical output
  system("echo $cmd_data >> $outputStatsFile");

  $firstRun = 0;
  my $time_stamp = `date +"%Y-%m-%d %H:%M:%S"`;
  chomp $time_stamp;
  print RAW "$time_stamp - ",(time()-$begin)," sec(s) processing time\n";
  $sleeptime = $refresh - (time()-$begin);
  if ($sleeptime > 0) {
    sleep $sleeptime;
  } else {
    sleep 10;
  }
}

#close(OUT);
#close(RAW);
#exit(0);

###################################################################
# Check if new month and create new directory
sub checkMonthRollover{
    $zone = `/usr/bin/uname -n`;
    chomp $zone;
    $monthdir = `date +"/home/bfausey/logs/%m%y%d"`;
    chomp $monthdir;
    if ($ROOTDIR ne $monthdir) {
        $ROOTDIR = $monthdir;
        if (!-d "$ROOTDIR") {
            mkdir $ROOTDIR or do { print "Invalid ROOTDIR ($ROOTDIR) $!\n";
                                   &QUIT_handler("Directory Create Error"); }
        }
    }
}
###################################################################
sub checkHourRollover{
    &checkMonthRollover();
    $new_filedate = `date +%Y%m%d`;
    chomp $new_filedate;
    if ($new_filedate ne $filedate){
        if (defined OUT){
            print "Closing file $outputFile...\n";
            close(OUT);
        }
        if (defined RAW) {
            print "Closing file $outputRawFile...\n";
            close(RAW);
        }
        # Build filename to open
        $outputFile = sprintf "%s/monses.%s", $ROOTDIR, $new_filedate;
        $outputRawFile = sprintf "%s/monsesRaw.%s", $ROOTDIR, $new_filedate;
        $outputStatsFile = sprintf "%s/monsesStats.%s", $ROOTDIR, $new_filedate;
        # open up output file
        open (OUT, ">> $outputFile");
        open (RAW, ">> $outputRawFile");
        OUT->autoflush(1);
        RAW->autoflush(1);
        #update filedate
        $filedate = $new_filedate;
    }
}
###################################################################
sub QUIT_handler {
    my $signame = shift;
    my $time = `date +"%Y-%m-%d %H:%M:%S"`;
    print "\n=================\n ";
    print "Got signal $signame at $time ";
    if (defined OUT){
        print "Closing file $outputFile...\n";
        close(OUT);
    }
    if (defined RAW) {
        print "Closing file $outputRawFile...\n";
        close(RAW);
    }
    exit;
}
###################################################################
#
# Print a usage statement and exit.
#
sub usageexit {
  print "Usage: monses.pl -i instance\n";
  print "  instance = INFOMRIXSERVER\n";
  print "This script monitors Informix Sessions for problem SQL\n";
  exit;
}
