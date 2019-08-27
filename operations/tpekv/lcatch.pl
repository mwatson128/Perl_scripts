#!/bin/perl
# (]$[) lcatch.pl:1.2 | CDATE=04/26/02 12:59:57
# lcatch filter

# Set up environment 
if ($ARGV[0]) {
  $rootdir = $ARGV[0];
} else {
  $rootdir = ".";
}

# Set name of log file
$filebase = "lcatch";

# Change directory to rootdir
chdir $rootdir;

# Get the curent time in GMT
($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst) = gmtime(time);
$year = $year % 100;
$month++;

# Create date dependant variables
$monthdir = sprintf "%02d%02d", $month, $year;

# Create the month directory in the unlikly event that this is the first 
# process to write to this directory.
`mkdir $monthdir 2> /dev/null`;

# Be lazy and use STDOUT's file pointer
close STDOUT;

while ($line = <STDIN>) {
  ($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst) = gmtime(time);
  $year = $year % 100;
  $month++;
  $filedate = sprintf "%02d%02d%02d", $month, $day, $year;
  $monthdir = sprintf "%02d%02d", $month, $year;
  
  $outfile = sprintf "%s/%s/%s.%s", $rootdir, $monthdir, $filebase, $filedate;
  open STDOUT, ">> $outfile" or die "Can't open $outfile.\n";
  print $line;
  close STDOUT;
}

