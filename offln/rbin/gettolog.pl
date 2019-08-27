#!/usr/local/bin/perl
# (]$[) gettolog.pl:1.12 | CDATE=03/04/13 18:53:55
#####################################################################
# This script will take the tolog file that is produced on usw_test #
# and break it up by HRS and dump it to the proper file.            #
#####################################################################

$zone = `uname -n`;
chomp $zone;

############################
# Set up general variables #
############################
$rootdir = "/$zone/usw/reports/daily/tologs";
$master_config = "/$zone/loghist/uswprod01/master/master.cfg";
$secperday = "86400";
#################################################################
# Check to see if the command line arg is a date, and use it as #
# such it is.                                                   #
#################################################################
if ($ARGV[0] =~ /^\d\d\/\d\d\/\d\d$/) {
  $date = $ARGV[0];
  ($month, $day, $year) = split /\//, $date;
} else {
  $time = time - $secperday;
  ($j, $j, $hour, $day, $month, $year, $j, $j, $j) = gmtime $time;
  $year = $year % 100;
  $month++;
  if ($year < 10) {
    $year = "0" . $year;
  }
  if ($month < 10) {
    $month = "0" . $month;
  }
  if ($day < 10) {
    $day = "0" . $day;
  }
  $date = $month . "/" . $day . "/" . $year;
}
$sday = $day + 0;
$destfile = "/$zone/usw/reports/daily/tologs/" . $month . $year . "/tolog" . $sday;

######################################################
# Read master.cfg and build a list of type A HRS ids #
######################################################
open MASTER, $master_config  or  die "Can't open MASTER file.\n";
while ($line = <MASTER>) {
  if ($line !~ /^$|^#/) {
    $hold = "";
    while ($line =~ /\\$/) {
      chomp $line;
      chop $line;
      $hold = $hold . $line;
      $line = <MASTER>;
    }
    chomp $line;
    $hold = $hold . $line;
    if ($hold =~ /{/) {
      chop $hold;
      chop $hold;
      $config_type = $hold;
      %hold = ();
    } elsif ($hold =~ / = /) {
      ($key, $value) = split / = /, $hold;
      $hold{$key} = $value;
    } else {
      if ($config_type eq "HRS_EQUIVALENCE") {
        $hrs_equi{$hold{PRIMARY_ID}} = $hold{HRS};
      } elsif ($config_type eq "A_IP_PROFILE") {
        if ($hold{FLAGS} =~ /NOCFDB/) {
          push @nocfdb, $hold{PRIMARY_ID};
        }
      }
    }
  }
}
push @hrslist, "ALL";
for $hrs (sort keys %hrs_equi) {
  push @hrslist, $hrs;
  $hrslist = $hrslist . " " . $hrs;
}

#####################################################
# Open the tolog file and read the data into a hash #
#####################################################
open TOLOG, $destfile or die "Can't open TOLOG\n";
$line = <TOLOG>;
$line =~ /(\d\d\/\d\d\/\d\d)/;
$date = $1;
$line = <TOLOG>;
$line = <TOLOG>;
@line = split / +/, $line;
$hrs = $line[0];
while ($line = <TOLOG>) {
  if ($line =~ /^Total/) {
    $hrsdata{$hrs} = $hrsdata{$hrs} . $line;
    $line = <TOLOG>;
    $hrsdata{$hrs} = $hrsdata{$hrs} . $line;
    $line = <TOLOG>;
    @line = split / +/, $line;
    $hrs = $line[0];
    if ($hrs eq "") {
      $hrs = "ALL";
    }
  } 
  $hrsdata{$hrs} = $hrsdata{$hrs} . $line;
}
close TOLOG;
