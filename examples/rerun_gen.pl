#!/usr/bin/perl

# Global variables

# Three character day name
@abrv_day_name = qw(
   Sun Mon Tue Wed Thu Fri Sat
);

# Number of days in each month
%year_day_num = (
	0 => 31, 1 => 28, 2 => 31, 3 => 30, 4 => 31, 5 => 30,
	6 => 31, 7 => 31, 8 => 30, 9 => 31, 10 => 30, 11 => 31
);

# Usage statement
$us = "usage: $0 mm dd yy startday [DEBUG]
  mm = month you wish run billing for
  dd = day to start billing, it automatically continues through
       the last day of the givin month
  yy = year associated to the month you want to run billing for.
  startday = day 0-6, Sunday being 0, that corresponds to the 
       associated mm dd yy
  DEBUG = the word 'DEBUG' will cause the program to print out 
       the command line arguments as it sees them, then exit.
print to stdout the daybill.pl rerun script for a 
specific month.\n";

$ARGC = @ARGV;
if ( $ARGC < 4) {
  print $us;
  exit 1;
}else {

  $prog = "daybill.pl";
  $mn = $ARGV[0];
  $dy = $ARGV[1];
  $yr = $ARGV[2];
  $startday = $ARGV[3];
  if ($ARGC == 5 && $ARGV[4] eq "DEBUG") {
    $DEBUG = true;
  }

}

if ($DEBUG) {
  print "Month:$mn Day:$dy Year:$yr Startday:$abrv_day_name[$startday]\n";
  exit 0;
}


for ($i = 0; $i < $year_day_num{$mn - 1}; $i++) {

  if ($startday == 7) {
    $startday = 0;
  }

  $holding = sprintf "%s %02d/%02d/%02d %s\n",
         $prog, $mn, $dy++, $yr, $abrv_day_name[$startday++];

  print $holding;
}

