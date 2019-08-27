#!/usr/local/bin/perl
# (]$[) daycttm.pl:1.5 | CDATE=01/18/08 08:44:23
######################################################################
#  This script will deliver a 14 day history on the context timeout  #
#  summary report.  It feed off a config file called daycttm.cfg     #
#  that is located in /usw/offln/bin.                                #
######################################################################

######################################################################
# This sets the date to run, which is a numerical value set to the 
# number of days back you want to run the report for.
######################################################################
$deltaday = 1;
if ($ARGV[0] =~ /\d\d*/) {
  $deltaday = $ARGV[0];
}

#########################
# General variable setup
#########################
@week_names = qw "Sun Mon Tue Wed Thu Fri Sat";
$secperday = "86400";
$deltasecs = $secperday * $deltaday;
$linesperday = "14";
$zone = `uname -n`;
chomp $zone;

######################################
# Produce the date and time variables
######################################
$time = time;
($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst) = gmtime $time - $deltasecs;
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
$tologfile = "/$zone/usw/reports/daily/tologs/" . $month . $tdyear . "/tolog" . $day;
$tologdir = "/$zone/usw/reports/daily/tologs/summary";
$master_config = "/$zone/loghist/uswprod01/master/master.cfg";
$config_file = "/$zone/usw/offln/bin/daycttm.cfg";

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
# Added "ALL" tothe list for ease of  processing.
##################################################
push @hrslist, "ALL";
for $hrs (sort keys %hrs_equi) {
  push @hrslist, $hrs;
  $hrslist = $hrslist . " " . $hrs;
}

########################################
# Generate data for summary file update
########################################
open TOLOG, $tologfile or die "Can't open $tologfile\n";
$line = <TOLOG>;
$line =~ /(\d\d\/\d\d\/\d\d)/;
$date = $1;
$line = <TOLOG>;
$line = <TOLOG>;
@line = split / +/, $line;
$hrs = $line[0];
while ($line = <TOLOG>) {
  if ($line =~ /^Total/) {
    chomp $line;
    @line = split / +/, $line;
    shift @line;
    $total = pop @line;
    @{$hrsdata{$hrs}} = @line;
    $total{$hrs} = $total;
    $line = <TOLOG>;
    $line = <TOLOG>;
    @line = split / +/, $line;
    $hrs = $line[0];
    if ($hrs eq "") {
      $hrs = "ALL";
    }
  } 
}
close TOLOG;

####################################################
# Update the sumamry files based on data from tolog
####################################################
for $hrs (@hrslist) {
  $outfile = $tologdir . "/" . lc $hrs . ".cttm";
  open FIL, ">> $outfile" or die "Can't open $outfile\n";
  printf FIL "%s: %s    %6d  %6d  %6d  %6d  %6d  %6d  %6d  %6d\n",
              $dof, $date, $total{$hrs}, @{$hrsdata{$hrs}}; 
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
    $subject = sprintf "Daily Context Timeout Summary for %s on %s", $username, $date;
    $hrs = "ALL";
    close STDOUT;
    open STDOUT, "> $mailfile" or die "Can't open $mailfile\n";
    $command = sprintf "/bin/tail -%d %s/%s.cttm", $linesperday, $tologdir, lc $hrs;
    printf "Daily Context Timeout Summary for %s\n\n", $hrs;
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
        $command = sprintf "/bin/tail -%d %s/%s.cttm", $linesperday, $tologdir, lc $hrs;
        printf "Daily Context Timeout Summary for %s\n\n", $hrs;
        print " " x 18 . "Total      AA      UA      1P      1A      WB      MS      HD\n";
        @filetail = `$command`;
        for $line (@filetail) {
          print $line;
        }
        print "\n\n";
      }
      for $hrs (@hrslist) {
        if ($sentlist{$hrs} ne "SENT") {
          $command = sprintf "/bin/tail -%d %s/%s.cttm", $linesperday, $tologdir, lc $hrs;
          printf "Daily Context Timeout Summary for %s\n\n", $hrs;
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
        $command = sprintf "/bin/tail -%d %s/%s.cttm", $linesperday, $tologdir, lc $hrs;
        printf "Daily Context Timeout Summary for %s\n\n", $hrs;
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
