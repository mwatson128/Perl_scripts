#!/usr/local/bin/perl
# (]$[) winstat.pl:1.8 | CDATE=04/26/04 15:24:35
# Script designed to take a list of IP address off the command line
# and report the send and receive window and queue sizes.  It updates
# every 60 seconds, and will run for an hour.
######################################################################

######################
# Running Environment
######################
# List of IP addresses to monitor
@iplist = ( 
           ".9300",		# Hyatt Type A
           ".9052",		# Red Roof Type A
           ".7000",		# West Coast Type A
           ".9314",		# Omni Type A
           ".9100",		# Wyndham Type A
           ".10411",		# Hilton Type A
           ".10410",		# Promus Type A
           ".10103",		# AA2-A2;listen 10.64.44.
           ".10001"		# TCPSES Connection
          );

#####################################################
# Set up filter as a pipe delimited list of the args
#####################################################
for $arg (@iplist) {
  if ($iplist[$#iplist] ne $arg) {
    $filter .= $arg . "\|";
  } else {
    $filter .= $arg;
  }
}

#############################################################
# Get system name and user id to determine logging directory
#############################################################
$machine = `uname -n`;
$user = `/bin/id | cut -d"(" -f2 | cut -d")" -f1`;
chomp $machine;
chomp $user;

if ($user eq "qa") {
  if ($machine =~ /usw./) {
    $dirbase = "/qa/perf/kv";
  } else {
    $dirbase = "/usr/usw/qa/kv";
  }
} elsif ($user eq "usw") {
  if ($machine =~ /usw./) {
    $dirbase = "/prod/perf/kv";
  } else {
    $dirbase = "/usr2/usw/perf/kv";
  }
} else {
  printf "Unknown user: $user\n";
  exit;
}

#############################################################
# Get the date information to complete the logging directory
#############################################################
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime time;
$mon++;
$year = $year % 100;
$day = $mday;
$basename = "winstat";
$logfile = sprintf "%s/%02d%02d/%s.%02d%02d%02d", 
                   $dirbase, $mon, $year, $basename, $mon, $day, $year;

###########################
# Point STDOUT to $logfile
###########################
close STDOUT;
open STDOUT, ">> $logfile" or die "Can\'t open $logfile.\n";
$|=1;

########################################################################
# Set the sleep durration in seconds and calculate the iterations based 
# on a one hour runtime.
########################################################################
$sleep_time = 60; 
$iterations = (3600 / $sleep_time) - 1;

#################
#  Drop a header
#################
print "       Time            Remote Host       swind  sendq rwind  recvq\n";

##########################
# Loop through iterations
##########################
for ($i = 0;$i < $iterations;$i++) {

  ###################################
  # Grab time and set $time variable
  ###################################
  ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime time;
  $mon++;
  $year = $year % 100;
  $day = $mday;
  $time = sprintf "%02d\/%02d\/%02d %02d:%02d:%02d", 
                  $mon, $day, $year, $hour, $min, $sec;

  ###############################
  # Grab and parse netstat data.
  ###############################
  @NETOUT=`/bin/netstat -an`;
  for $line (@NETOUT) {
    if ($line =~ /$filter/) {
      @line = split / +/, $line;
      $src = $line[0];
      $dest = $line[1];
      $swind = $line[2];
      $sendq = $line[3];
      $rwind = $line[4];
      $recvq = $line[5];
      $state = $line[6];
      printf "%s %-20s  %6d %5d %6d %5d\n", $time, $dest, $swind, $sendq, $rwind, $recvq;
    }
  }
  sleep $sleep_time;
}
