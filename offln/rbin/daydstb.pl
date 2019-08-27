#!/usr/local/bin/perl
# (]$[) daydstb.pl:1.1 | CDATE=05/27/08 16:21:45
######################################################################
#  This script will deliver a 14 day history on the destination busy #
#  summary report.  It feed off a config file called daydstb.cfg     #
#  that is located in /usw/offln/bin.                                #
######################################################################

#########################
# General variable setup
#########################
@week_names = qw "Sun Mon Tue Wed Thu Fri Sat";
$linesperday = "14";
$zone = `uname -n`;
chomp $zone;

######################################
# Produce the date and time variables
######################################

# Set Month / Day just in case it isn't entered on the command line
($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst)=gmtime(time);
$month++;

if ($ARGV[0]) {
  if ($ARGV[0] =~ /^\d\d\/\d\d\/\d\d$/) {
    $DATE = $ARGV[0];
  } else {
    print STDERR "Incorrect Date format.";
  }
} else {
  $DATE=`/uswsup01/usw/offln/bin/getydate -s`;
}

# Parse out the date, and set the day, month and year variables
$timesecs=`/uswsup01/usw/offln/bin/tstamp -t $DATE -od`;

($sec, $min, $hour, $day, $month, $year, $week, $j, $isdst) = gmtime($timesecs);
$year = $year + 1900;
$tdyear = $year % 100;
if ($tdyear < 10) {
  $tdyear = "0" . $tdyear;
}
$month++;
if ($month < 10) {
  $month = "0" . $month;
}
if ($day < 10) {
  $date = $month . "/" . "0" . $day . "/" . $tdyear;
} else {
  $date = $month . "/" . $day . "/" . $tdyear;
}
$day = $day + 0;
$dof = $week_names[$week];

##############################################
# Build variables that are based on the date.
##############################################
$dblogfile = "/$zone/usw/reports/daily/dstblogs/" . $month . $tdyear . "/dblog" . $day;
$dblogdir = "/$zone/usw/reports/daily/dstblogs/summary";
$master_config = "/$zone/loghist/uswprod01/master/master.cfg";
$config_file = "/$zone/usw/offln/bin/daydstb.cfg";

###########################################################
# Generate a list of HRS ids based on the master.cfg file.
###########################################################
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
##################################################
# Added "ALL" to the list for ease of  processing.
##################################################
push @hrslist, "ALL";
for $hrs (sort keys %hrs_equi) {
  push @hrslist, $hrs;
  $hrslist = $hrslist . " " . $hrs;
}

########################################
# Generate data for summary file update
########################################
open DBLOG, $dblogfile or die "Can't open $dblogfile\n";
$line = <DBLOG>;
$line =~ /(\d\d\/\d\d\/\d\d)/;
$date = $1;
$line = <DBLOG>;
$line = <DBLOG>;
@line = split / +/, $line;
$hrs = $line[0];
while ($line = <DBLOG>) {
  if ($line =~ /^Total/) {
    chomp $line;
    @line = split / +/, $line;
    shift @line;
    $total = pop @line;
    @{$hrsdata{$hrs}} = @line;
    $total{$hrs} = $total;
    $totalAA = $totalAA + $line[0];
    $totalUA = $totalUA + $line[1];
    $total1P = $total1P + $line[2];
    $total1A = $total1A + $line[3];
    $totalWB = $totalWB + $line[4];
    $totalMS = $totalMS + $line[5];
    $totalHD = $totalHD + $line[6];
    $hrs = ALL;
    $total{$hrs} += $total;
    $line = <DBLOG>;
    $line = <DBLOG>;
    @line = split / +/, $line;
    $hrs = $line[0];
    if ($hrs eq "") {
      $hrs = "NONE";
    }
  } 
}
close DBLOG;

####################################################
# Update the sumamry files based on data from dblog
####################################################
for $hrs (@hrslist) {
  $outfile = $dblogdir . "/" . lc $hrs . ".dstb";
  open FIL, ">> $outfile" or die "Can't open $outfile\n";
  if ($hrs eq "ALL") {
    printf FIL "%s: %s    %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d\n",
                $dof, $date, $total{$hrs}, $totalAA, $totalUA, $total1P, 
		$total1A, $totalWB, $totalMS, $totalHD;
  }
  else {
    printf FIL "%s: %s    %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d\n",
                $dof, $date, $total{$hrs}, @{$hrsdata{$hrs}}; 
  }
  close FIL; 
}
###################################
# Take out "ALL" from list of HRSs
###################################
shift @hrslist;

##############################################################
# Go through the config file and send the appropriate reports
##############################################################
open CONFIG, $config_file or die "Can't open $config_file\n";
while ($line = <CONFIG>) {
  if ($line !~ /^$|^#/) {
    $hold = "";
    while ($line =~ /\\$/) {
      chomp $line;
      chop $line;
      $hold = $hold . $line;
      $line = <CONFIG>;
    }
    chomp $line;
    $hold = $hold . $line;
    @line = split /\|/, $line;
    $email = shift @line;
    $username = shift @line;
    @sendlist = @line;
    $mailfile = "/tmp/mailtemp." . $$;
    $subject = sprintf "Daily Destination Busy Summary for %s on %s", $username, $date;
    $hrs = "ALL";
    close STDOUT;
    open STDOUT, "> $mailfile" or die "Can't open $mailfile\n";
    $command = sprintf "/bin/tail -%d %s/%s.dstb", $linesperday, $dblogdir, lc $hrs;
    printf "Daily Destination Busy Summary for %s\n\n", $hrs;
    print " " x 18 . "Total      AA      UA      1P      1A      WB      MS      HD\n";
    for $line (`$command`) {
      print $line;
    }
    print "\n\n";
    %sentlist = ();
    if ($sendlist[0] eq "ALL") {
      shift @sendlist;
      for $hrs (@sendlist) {
        $sentlist{$hrs} = "SENT";
        $command = sprintf "/bin/tail -%d %s/%s.dstb", $linesperday, $dblogdir, lc $hrs;
        printf "Daily Destination Busy Summary for %s\n\n", $hrs;
        print " " x 18 . "Total      AA      UA      1P      1A      WB      MS      HD\n";
        @filetail = `$command`;
        for $line (@filetail) {
          print $line;
        }
        print "\n\n";
      }
      for $hrs (@hrslist) {
        if ($sentlist{$hrs} ne "SENT") {
          $command = sprintf "/bin/tail -%d %s/%s.dstb", $linesperday, $dblogdir, lc $hrs;
          printf "Daily Destination Busy Summary for %s\n\n", $hrs;
          print " " x 18 . "Total      AA      UA      1P      1A      WB      MS      HD\n";
          @filetail = `$command`;
          for $line (@filetail) {
            print $line;
          }
          print "\n\n";
        }
      }
    } else {
      for $hrs (@sendlist) {
        $command = sprintf "/bin/tail -%d %s/%s.dstb", $linesperday, $dblogdir, lc $hrs;
        printf "Daily Destination Busy Summary for %s\n\n", $hrs;
        print " " x 18 . "Total      AA      UA      1P      1A      WB      MS      HD\n";
        @filetail = `$command`;
        for $line (@filetail) {
          print $line;
        }
        print "\n\n";
      }
    } 
    close STDOUT;
    $command = sprintf "/bin/mailx -s \"%s\" %s < %s", $subject, $email, $mailfile;
    `$command`;
    system "rm -f $mailfile";
  }  
}
close CONFIG;
