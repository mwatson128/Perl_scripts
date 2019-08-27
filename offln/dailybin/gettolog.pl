#!/usr/local/bin/perl
# (]$[) gettolog.pl:1.11 | CDATE=01/18/08 08:40:56
#####################################################################
# This script will take the tolog file that is produced on usw_test #
# and break it up by HRS and dump it to the proper file.            #
# Then deliver that file to report1 for DSS to display to user      #
#####################################################################

$zone = `uname -n`;
chomp $zone;

############################
# Set up general variables #
############################
$rootdir = "/$zone/usw/reports/daily/tologs";
$dsslogdir = $rootdir . "/DSS";
$master_config = "/$zone/loghist/uswprod01/master/master.cfg";
$secperday = "86400";
$brio_logid = "brio";
$brio_host = "report1";
$brio_destdir = "/brio/ads/documents/outgoing";
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

######################################################
# Create a file for each HRS in the proper directory #
######################################################
for $hrs (@hrslist) {
  $hrsfile = $dsslogdir . "/" . lc $hrs . ".to";
  open HRSLOG, "> $hrsfile" or die "Can't open HRSLOG\n";
  print HRSLOG $hrsdata{$hrs};
  close HRSLOG;
}

#############################################
# Go through HRS list and push valid brands #
# for brio reports, use scp not rcp.        #
#############################################
for $hrs (@hrslist) {

  $hrs_file = $hrs;
  if ($hrs eq "RT") {
    $hrs_file = "XM";
  }

  # Don't push invalid HRSs
  if (
      $hrs ne "ALL" && 
      $hrs ne "LQR" && 
      $hrs ne "PRR" && 
      $hrs ne "ZZ" && 
      $hrs ne "us"
     ) {
    $hrsfile = $dsslogdir . "/" . lc $hrs . ".to";
    $briofile = sprintf "BRAND_%s_USW_Context_Timeouts-20%02d%02d%02d.to",
         $hrs_file, $year, $month, $day;
    $scp_cmd = sprintf "/usr/local/bin/scp %s %s\@%s:%s/%s", $hrsfile, 
         $brio_logid, $brio_host, $brio_destdir, $briofile;
    system $scp_cmd;
  }
}
