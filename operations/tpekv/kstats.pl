#!/bin/perl
# (]$[) kstats.pl:1.18 | CDATE=04/29/07 15:38:15
# Uses kstats to get Kivanet shared memory locking statistics and outputs
# the counts/sec for the interval

# Get user ID and hostname to determine environment
$id = `/usr/bin/id`;
$id =~ /uid.*\((.*)\) gid/;
$username = $1;
$hostname = `/usr/bin/uname -n | cut -d . -f 1`; 
chomp $hostname;

# Set root logging directory based on login and system name
if ($hostname =~ /^usw|^pegsdb|^dhsc/) {
  if ($username eq "usw") {
    $sleep_time = "10";
    $rootdir = "/$hostname/perf/kv";
    $kstats_prog = "$ENV{KNETPATH}/kstats";
  } 
  else {
    $sleep_time = "10";
    $rootdir = "/$hostname/perf/kv";
    $kstats_prog = "$ENV{KNETPATH}/kstats";
  }
} 
else {
  if ($username eq "usw") {
    $sleep_time = "60";
    $rootdir = "/usr2/usw/perf/kv";
    $kstats_prog = "/usr2/usw/prod/knetbin/kstats";
  } 
  else {
    $sleep_time = "60";
    $rootdir = "/usr/usw/uat/kv";
    $kstats_prog = "/usr/usw/uat/knetbin/kstats";
  }
}

# Set interval between data collection, and calculate iterations 
# based on interval.
$iterations = 3600 / $sleep_time;

# Get the time to print the header and open logging file 
($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst) = gmtime(time);
$year %= 100;
$month++;
$monthdir = sprintf "%02d%02d", $month, $year;

# Build filename to open 
$filename = sprintf "%s/%s/kstats.%02d%02d%02d", 
     $rootdir, $monthdir, $month, $day, $year;

# Be lazy and use the STDOUT file pointer also create monthdir in the unlikly
# event that this is the first data gathering script to write to the new month.
`/usr/bin/mkdir $rootdir/$monthdir 2> /dev/null`;
close STDOUT;
open STDOUT, ">> $filename" or die "Can't open $filename.\n";

# Print the header and gather first iteration of data
printf "%02d/%02d/%02d                     spin to gate   spin to release backoff reqs backoff\n", $month, $day, $year;
print "  time   pcnt   reqs    succ none some spin none some spin none some fail   iter\n";

# Close file
close STDOUT;

# grab first iteration of data
@kstats = `$kstats_prog -l`;

$kstats[1] =~ /requests (-*\d+),.* (-*\d+)/;
$kstats_new[0] = $1;
$kstats_new[1] = $2;
 
$kstats[2] =~ /none (-*\d+),.* (-*\d+),.* (-*\d+)/;
$kstats_new[2] = $1;
$kstats_new[3] = $2;
$kstats_new[4] = $3;
  
$kstats[3] =~ /none (-*\d+),.* (-*\d+),.* (-*\d+)/;
$kstats_new[5] = $1;
$kstats_new[6] = $2;
$kstats_new[7] = $3;

$kstats[5] =~ /None required (-*\d+),.* (-*\d+),.* (-*\d+)/;
$kstats_new[8] = $1;
$kstats_new[9] = $2;
$kstats_new[10] = $3;

$kstats[6] =~ /(-*\d+)/;
$kstats_new[11] = $1;

for ($j=0;$j < $iterations;$j++) {

  # sleep 
  sleep $sleep_time;

  # Copy new variables into old variables
  @kstats_old = @kstats_new;
 
  # Get the time of kstats sample and build time variables
  ($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst) = 
       gmtime(time);
  $year %= 100;
  $month++;
  $monthdir = sprintf "%02d%02d", $month, $year;
  $time = sprintf "%02d:%02d:%02d", $hour, $min, $sec;
  
  # Get next iteration of data from kstats
  @kstats = `$kstats_prog -l`;
  
  $kstats[1] =~ /requests (-*\d+),.* (-*\d+)/;
  $kstats_new[0] = $1;
  $kstats_new[1] = $2;
  
  $kstats[2] =~ /none (-*\d+),.* (-*\d+),.* (-*\d+)/;
  $kstats_new[2] = $1;
  $kstats_new[3] = $2;
  $kstats_new[4] = $3;
  
  $kstats[3] =~ /none (-*\d+),.* (-*\d+),.* (-*\d+)/;
  $kstats_new[5] = $1;
  $kstats_new[6] = $2;
  $kstats_new[7] = $3;

  $kstats[5] =~ /None required (-*\d+),.* (-*\d+),.* (-*\d+)/;
  $kstats_new[8] = $1;
  $kstats_new[9] = $2;
  $kstats_new[10] = $3;

  $kstats[6] =~ /(-*\d+)/;
  $kstats_new[11] = $1;

  # Calculate change between old and new iteration and then counts/sec  
  for ($i=0;$i<$#kstats_new + 1;$i++) {
    # kstats rolls from 2,147,483,647 to -2,147,483,648
    if (0 > $kstats_new[$i] && 0 < $kstats_old[$i]) {
      $kstats_tmp = 2147483647 + (2147483647 + $kstats_new[$i]);
      $kstats_delta[$i] = abs ($kstats_tmp - $kstats_old[$i]);
    }
    else {
      $kstats_delta[$i] = abs ($kstats_new[$i] - $kstats_old[$i]);
    }
    $kstats_persec[$i] = sprintf "%d", $kstats_delta[$i] / $sleep_time;

    # If we are position 2-10 max value to 9999
    if ($i != 0 && $i != 1 && $i != 11) {
      if ($kstats_persec[$i] > 9999) {
        $kstats_persec[$i] = "9999";
      }
    }

    # If we are position 11 max value at 999999
    elsif ($i == 11) {
      if ($kstats_persec[$i] > 999999) {
        $kstats_persec[$i] = 999999
      }
    }
  }

  # Build filename to open 
  $filename = sprintf "%s/%s/kstats.%02d%02d%02d", 
       $rootdir, $monthdir, $month, $day, $year;

  # Open the logging file to write statistics.
  `mkdir $rootdir/$monthdir 2> /dev/null`;
  close STDOUT;
  open STDOUT, ">> $filename" or die "Can't open $filename.\n";

  # Calculate the success percentage
  if ($kstats_persec[0] != 0) {
    $rec_succ_pcnt = sprintf "%d", 
         100 * ($kstats_persec[1] / $kstats_persec[0]);
  }
  
  # print statistics for this iteration
  printf "%s %3.3s %7.7s %7.7s " . "%4.4s " x 9 . "%6.6s\n", 
       $time, $rec_succ_pcnt, @kstats_persec;

  # Close file to flush buffer
  close STDOUT;
}
