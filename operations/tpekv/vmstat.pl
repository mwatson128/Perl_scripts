#!/bin/perl
# Gather vmstat date, grabbing the fields we want to see and log it to a 
# file.
# (]$[) vmstat.pl:1.9 | CDATE=04/29/07 15:38:22


######################
# Set up environment #
######################

# Get system name
$sysname = `/usr/bin/uname -n | cut -d . -f 1`;
chomp $sysname;

# Get username
$id = `/usr/bin/id`;
$id =~ /^uid=.*\((.*)\) gid/;
$username = $1;

# Set the logging directory based on the system name and username
if ($username eq "usw") {
  if ($sysname =~ /^usw.|^tusw|^dhsc/) {
    $logroot = "/$sysname/perf/kv";
  }
  else {
    $logroot = "/usr2/usw/perf/kv";
  }
}
elsif ($username eq "uat") {
  if ($sysname =~ /^usw.|^tusw|^dhsc/) {
    $logroot = "/$sysname/perf/kv";
  }
  else {
    $logroot = "/usr/usw/perf/kv";
  }
} 
else {
  print "You must be logged in as uat or usw\n";
  exit;
}

# Basename of the logging file
$filebase = "vmstat";

# Set the delay to the command line and compute iters
if ($ARGV[0]) {
  $delay = $ARGV[0];
} else {
  $delay = "60";
}
$iters = (3600 / $delay) - 1;
$first_time = "TRUE";

########################
#  Lets start working! #
########################
for ($i = 0;$i < $iters;$i++) {
  
  #  run vmstat and capture data.  -S will give swapping statistics
  @out = `/usr/bin/vmstat -S M $delay 2`;

  # Get the time
  ($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst) = 
      gmtime(time);
  $month++;
  $year %= 100;

  # Build the timestamp
  $time = sprintf "%02d:%02d:%02d", $hour, $min, $sec;

  # Split the fourth line of the vmstat output.  The first two lines
  # are headers, and the third is invalid
  chomp $out[1];
  chomp $out[3];
  
  # Build the log dir
  $lgdir = sprintf "%02d%02d", $month, $year;

  qx(/usr/bin/mkdir $logroot/$lgdir 2> /dev/null);

  # Build filename with full path
  $file = sprintf "%s/%s/%s.%02d%02d%02d", 
     $logroot, $lgdir, $filebase, $month, $day, $year;

  # Open the file
  open LOG, ">> $file" or die "Can't open $file\n";

  if ($first_time eq "TRUE") {
    printf LOG "  TIME   %s\n", $out[1];
    $first_time = "FALSE";
  }
  printf LOG "%8s %s\n", $time, $out[3];

  # Close the file
  close LOG;
}
