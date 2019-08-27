#!/bin/perl
###########################################################################
# %M% - Script for month end billing for Ultraswitch. %I%
# (]$[) %M%:%I% | CDATE=%G% %U%
###########################################################################
#
# Perl script to automate the data gathering needed to compile Month end
# Ultraswitch billing.  This script reads in the /usw/reports/monthly/perf
# and /usw/reports/monthly/perfb reports and makes a load file for the 
# usw_perf:rtp_perf table containing DSS pertinent info.
# 
# Example: %M% 
#
###########################################################################

@tmp_mon = split //, `pvmon`;
$prev_mon = "20" . $tmp_mon[2] . $tmp_mon[3] . "-" . $tmp_mon[0] . $tmp_mon[1];

$gds_var = 0;
$rptcnt = 0;
$f1st = 1;

$perfdir = "/uswsup01/usw/reports/monthly/perf/";
$perfbdir = "/uswsup01/usw/reports/monthly/perfb/";


# Read in the perf A file.
@list = `ls $perfdir /uswsup01/usw/reports/monthly/perf/gds/1p*`;

foreach $f (@list) {

  chomp $f; 

  if ($f =~ /perf\/gds\/1p/) {
    $a_file = $f;
    $f =~ s/perf/perfb/g;
    $b_file = $f;
  }
  else {
    $a_file = $perfdir . $f;
    $b_file = $perfbdir . $f;
    $b_file .= "b";
  }

  if (-f $a_file) {
    
    # Set the date.
    $record[$rptcnt][0] = $prev_mon;

    # Go through the a_file first...
    @fileptr1 = `cat $a_file`;
    @fileptr2 = `cat $b_file`;

    # go through each line of the type A file picking stuff out.
    foreach $ln (@fileptr1) {
      chomp $ln;

      if ($ln =~ /Distribution System/) {
	@tmp = split / +/, $ln;
	$record[$rptcnt][1] = $tmp[4];
      }
      if ($ln =~ /Reservation System/) {
	@tmp = split /:/, $ln;
	@chn = split /\|| +/, $tmp[1];
	$record[$rptcnt][2] = $chn[1];
      }

      if ($ln =~ /Mean/) {
        # Split this like up by white space looking for
	# the 4th and 5th elements.
	@tmp = split / +/, $ln;
        $record[$rptcnt][5] = $tmp[3];
        $record[$rptcnt][4] = $tmp[4];
      }
      if ($ln =~ /transactions processed/) {
        $ln =~ /(-*\d+)/;
        $record[$rptcnt][3] = $1;
      }
    }

    # go through each line of the type B file picking stuff out.
    foreach $ln (@fileptr2) {
      chomp $ln;
      
      if ($ln =~ /0 -   59/) {
	@tmp = split / +/, $ln;
	$record[$rptcnt][6] = $tmp[6];
      }
      
      if ($ln =~ /0 -   9/) {
	@tmp = split / +/, $ln;
	$record[$rptcnt][8] = $tmp[6];
      }
      
      if ($ln =~ /Msgs/ && $f1st) {
	@tmp = split / +/, $ln;
	$record[$rptcnt][9] = $tmp[2];
	$f1st = 0;
      }
      
      if ($ln =~ /Msgs/ && !$f1st) {
	@tmp = split / +/, $ln;
	$record[$rptcnt][7] = $tmp[2];
      }

    }

    # last thing, increment counter.
    $rptcnt++;
    $f1st = 1;
  }

}


# Print the load file.
for($i = 0; $i < $rptcnt; $i++) {

  $ln = $record[$i][0] . "|" . $record[$i][1] . "|" . $record[$i][2] . "|";
  $ln2 = $ln . $record[$i][3] . "|" . $record[$i][4] . "|" . $record[$i][5];
  $ln3 = $ln2 . "|" . $record[$i][6] . "|" . $record[$i][7] . "|";
  $ln4 = $ln3 . $record[$i][8] . "|" . $record[$i][9] . "|";
  print $ln4, "\n"; 
  
}

