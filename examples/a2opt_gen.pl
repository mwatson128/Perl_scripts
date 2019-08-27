#!/usr/bin/perl

# Global variables

# Number of days in each month
%year_day_num = (
	0 => 31, 1 => 28, 2 => 31, 3 => 30, 4 => 31, 5 => 30,
	6 => 31, 7 => 31, 8 => 30, 9 => 31, 10 => 30, 11 => 31
);

# Usage statement
$us = "usage: $0 mmyy
  mm = month you wish run billing for
  yy = year associated to the month you want to run billing for.
print to stdout the a2optally rerun script for a 
specific month.\n";

$ARGC = @ARGV;
if ( $ARGC < 1) {
  print $us;
  exit 1;
}else {

  $prog = "a2optally";
  @m = split //, $ARGV[0];
  $mn = $m[0] . $m[1];
  $yr = $m[2] . $m[3];
  $dy = 01;  		# assume the whole month is wanted.

}

# Print header info
print ": \n\n\n";

for ($i = 0; $i < $year_day_num{$mn - 1}; $i++) {

  $dy = $i + 1;

  $holding = sprintf "%s -t %02d/%02d/%02d_00:00 -u  %02d/%02d/%02d_07:59 >> ld_cnt_%02d\n", $prog, $mn, $dy, $yr, $mn, $dy, $yr, $mn;
  $holding2 = sprintf "%s -t %02d/%02d/%02d_08:00 -u  %02d/%02d/%02d_15:59 >> ld_cnt_%02d\n", $prog, $mn, $dy, $yr, $mn, $dy, $yr, $mn;
  $holding3 = sprintf "%s -t %02d/%02d/%02d_16:00 -u  %02d/%02d/%02d_23:59 >> ld_cnt_%02d\n", $prog, $mn, $dy, $yr, $mn, $dy, $yr, $mn;

  print $holding, $holding2, $holding3;
}

