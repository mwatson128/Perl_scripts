#!/usr/local/bin/perl
# (]$[) hour_perf.pl:1.7 | CDATE=05/14/03 22:05:21
#  Grab the per log from usw_prod, analyze it, and move the output to usw_prod

#########################################################
##  Check the time and build time dependant variables  ##
#########################################################
($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst) = gmtime(time - 3600);
$month2d = sprintf "%02d", ++$month;
$year2d = $year % 100;
$day2d = sprintf "%02d", $day;
$hour2d = sprintf "%02d", $hour;

############################################################
##  Over ride date time variables with command line args  ##
############################################################
if ($ARGV[0]) {
  ($month2d, $day2d, $year2d) = split /\//, $ARGV[0];
  $hour2d = $ARGV[1];
}


#########################
##  Environment setup  ##
#########################

# DBUG On/Off
$DBUG=0;

# System to pull per logs from
$system = "usw_prod";

# User to connect with
$user = "prod_sup";

# Directory where per logs are written to on $system
$logdir = "/prod/logs/lg2";

# Directory on $system where perf files are located
$perfdir = "/prod/perf/daily";

# Directory where work is done
$workdir = "/loghist/per";
$DBUG && print("workdir:$workdir\n");

# Full path to ulgscan
$ulgscan = "/usw/offln/bin/ulgscan";

# Name of per file
$perfile = sprintf "per%s%s%s.lg", $month2d, $day2d, $hour2d;
$DBUG && print("perfile:$perfile\n");

# Name of perf file
$perf_file = sprintf "perf.%s%s", $month2d, $day2d;
$DBUG && print("perf_file:$perf_file\n");

###################################
##  Forward Declare Subroutines  ##
###################################
sub get_files;
sub analyze_file;
sub clean_up;

##########
## MAIN ##
##########
get_files();
analyze_file();
clean_up();

##########################################################################
##  Subroutine:  get_files                                              ##
##  Grab the last per log file and the performance outfile for the day  ##
##########################################################################
sub get_files {

  $DBUG && print(">get_files\n");
  
  # Build command to get per file 
  $RCP_PER = sprintf "/bin/rcp %s\@%s:%s/%s %s", 
       $user, $system, $logdir, $perfile, $workdir;

  # Get the per file
  system $RCP_PER;

  $DBUG && print("<get_files\n");
}

#####################################################
##  Subroutine:  analyze_file                      ##
##  Analyze the per file obtained, and update the  ##
##  perf file with the results                     ## 
#####################################################
sub analyze_file {

  $DBUG && print(">analyze_file\n");
  
  # Create filter file
  open FILTER, "> $workdir/filter" or 
       die "Can't open $workdir/filter for writing.\n";
  print FILTER "adduswrec LGPER|RQTPALSRQ|RPTPALSRP||\n";
  print FILTER "adduswrec LGPER|RQTRPINRQ|RPTRPINRP||\n";
  print FILTER "adduswrec LGPER|RQTRPINRQ|RPTPRINRP||\n";
  print FILTER "adduswrec LGPER|RQTBOOKRQ|RPTBOOKRP||\n";
  print FILTER "adduswrec LGPER|RQTAVSTAT|RPTAVSTAT||\n";
  print FILTER "adduswrec LGPER|RQTPRINUP||\n";
  print FILTER "adduswrec LGPER|RQTAALSRQ|RPTAALSRP||\n";
  print FILTER "adduswrec LGPER|RQTPRSDUP|RPTPRSDUP||\n";
  print FILTER "adduswrec LGPER|RPTERRRP|UTTA||\n";
  print FILTER "adduswrec LGPER|RPTERRREP|UTTA||\n";
  print FILTER "find\nscan\nexit\n";
  close FILTER;

  $DBUG && print("Open:$workdir/$perfile\n");

  # Create file pointer to ulgscan pipe
  open ULGSCAN, "$ulgscan -f $workdir/filter $workdir/$perfile 2> /dev/null |" 
       or die "Can't create file pointer to ulgscan pipe.\n";

  # Read the lines from the  pipe and handle accordingly
  while ($line = <ULGSCAN>) {
    
    # A new message, grab the transaction type
    if ($line =~ /^utt=.,  rqt=(.*), rpt=(.*)/) {
      $trans_type = $1;
      $resp_type = $2;
      # Keep reading lines until we match the line with the trip times.  
      until ($line =~ /^DELTA/) {
        $line = <ULGSCAN>;
      }
      $DBUG && print("trans:$trans_type resp:$resp_type ");

      # Grab the grt and hrt times from the line
      $line =~ /^DELTA T: grt=(\d+) hrt=(\d+)/;
      $grt = $1;
      $hrt = $2;

      # Calculate the usw dwell time
      $uswdwell = $grt - $hrt;

      # If error use Response Type
      if ($resp_type eq "ERRRP" || $resp_type eq "ERRREP") {
        $DBUG && print("RESP\n");
    
        # Set to ERRRP for consistency
        $resp_type = "ERRRP";
    
        # Count the response 
        $num{$resp_type}++;
      
        # Sum up the USW dwell time
        $rtrip{$resp_type} += $uswdwell;
      }
      else {
        $DBUG && print("TRANS\n");
    
        # Count the transaction 
        $num{$trans_type}++;
      
        # Sum up the USW dwell time
        $rtrip{$trans_type} += $uswdwell;
      }
    } 
  }

  # Close the file pointer to the ulgscan pipe
  close ULGSCAN;

  # Let's calculate some response times!
  for $trans_type (sort keys %num) {
    if ($num{$trans_type} != 0) {
      $avg{$trans_type} = ($rtrip{$trans_type} / $num{$trans_type}) / 10;
    }
  }

  # Open perf update file
  open PERF, "> $workdir/perf.update" or 
       die "Can't open $workdir/perf.update for writing.\n";

  # If this is the 0 hour, print the header
  if ($hour2d eq "00") {
    printf PERF "Type A dwell times by txn type - %s%s\n\n", $month2d, $day2d;
    print PERF "HR";
    print PERF "  BOOK";
    print PERF "  PALS";
    print PERF "  RPIN";
    print PERF "  AALS";
    print PERF "    BOOK";
    print PERF "   PALS";
    print PERF "  RPIN";
    print PERF "  AALS";
    print PERF "   ERRR";
    print PERF "  AVST";
    print PERF " PRUP";
    print PERF " PRSD\n\n";
  }

  # Lets print our response times
  printf PERF "%02d", $hour2d;
  printf PERF " %5.3f", $avg{BOOKRQ};
  printf PERF " %5.3f", $avg{PALSRQ};
  printf PERF " %5.3f", $avg{RPINRQ};
  printf PERF " %5.3f", $avg{AALSRQ};
  printf PERF " | %5d", $num{BOOKRQ};
  printf PERF " %6d", $num{PALSRQ};
  printf PERF " %5d", $num{RPINRQ};
  printf PERF " %5d", $num{AALSRQ};
  printf PERF " %6d", $num{ERRRP};
  printf PERF " %5d", $num{AVSTAT};
  printf PERF " %4d", $num{PRINUP};
  printf PERF " %4d\n", $num{PRSDUP};

  # Close perf update file
  close PERF;

  # Update the perf file in production
  $UPDATE_PERF = sprintf "/bin/rsh -l %s %s \"cat >> %s/%s\" < %s/perf.update",
       $user, $system, $perfdir, $perf_file, $workdir;
  system $UPDATE_PERF;

  $DBUG && print("<analyze_file\n");
}

#######################################################
##  Subroutine:  clean_up                            ##
##  Remove the filter file and the perf.update file  ##
#######################################################
sub clean_up {
  $DBUG && print(">clean_up\n");
  
  # Build rm command
  $RM_CMD = "/bin/rm -f $workdir/filter $workdir/perf.update $workdir/$perfile";

  # Run rm command
  system $RM_CMD;

  $DBUG && print("<clean_up\n");
}
