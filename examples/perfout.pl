#!/usr/bin/perl

# Global variables

# Number of days in each month
%year_day_num = (
	0 => 31, 1 => 28, 2 => 31, 3 => 30, 4 => 31, 5 => 30,
	6 => 31, 7 => 31, 8 => 30, 9 => 31, 10 => 30, 11 => 31
);

# Usage statement
$us = "usage: $0 mm dd yy [DEBUG]
  mm = month you wish run billing for
  dd = day to start billing, it automatically continues through
       the last day of the givin month
  yy = year associated to the month you want to run billing for.
  DEBUG = the word 'DEBUG' will cause the program to print out 
       the command line arguments as it sees them, then exit.
print to stdout the a2optallty rerun script for a 
specific month.\n";

$ARGC = @ARGV;
if ( $ARGC < 2) {
    
  print $us;
  exit 1;

} elsif ($ARGC == 2) { 

  $prog = "a2optally";
  $mn = $ARGV[0];
  $dy = 1;
  $yr = $ARGV[1];

} elsif ($ARGC >= 3) {

  $prog = "a2optally";
  $mn = $ARGV[0];
  $dy = $ARGV[1];
  $yr = $ARGV[2];

  if ($ARGC == 5 && $ARGV[4] eq "DEBUG") {
    $DEBUG = true;
  }
}

if ($DEBUG) {
  print "Month:$mn Day:$dy Year:$yr Startday:$abrv_day_name[$startday]\n";
  exit 0;
}


for ($i = 0; $i < $year_day_num{$mn - 1}; $i++) {

  $hold1 = sprintf "%s -t %02d/%02d/%02d_00:00 -u %02d/%02d/%02d_07:59:59\n",
         $prog, $mn, $dy, $yr, $mn, $dy, $yr;
  $hold2 = sprintf "%s -t %02d/%02d/%02d_08:00 -u %02d/%02d/%02d_15:59:59\n",
         $prog, $mn, $dy, $yr, $mn, $dy, $yr;
  $hold3 = sprintf "%s -t %02d/%02d/%02d_16:00 -u %02d/%02d/%02d_23:59:59\n",
         $prog, $mn, $dy, $yr, $mn, $dy, $yr;
  $dy++;

  print $hold1, $hold2, $hold3;
}

