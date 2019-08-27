#!/usr/local/bin/perl
# (]$[) hour_perf.pl:1.15 | CDATE=12/07/12 22:17:05
#
# Grab the per logs from uswprod01-04, join them into a single file,
# analyze it, and move the output to uswprod01

#########################################################
##  Check the time and build time dependant variables  ##
#########################################################
($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst) = gmtime(time - 3600);
$month2d = sprintf "%02d", ++$month;
$year2d = $year % 100;
$day2d = sprintf "%02d", $day;
$hour2d = sprintf "%02d", $hour;

#########################
##  Environment setup  ##
#########################

# DBUG On/Off
$DBUG = 0;

# User to connect with
$user = "usw";

# Directory on $system where perf files are located
$perfdir = "/uswprod01/perf/daily";

# Systems to pull per logs from
@system_list = qw ( uswprod01 uswprod02 uswprod03 uswprod04 );

# Directory where work is done
$workdir = "/uswsup01/research/";
$DBUG && print("workdir:$workdir\n");

# Full path to ulgscan / rpt_join
$ulgscan = "/uswsup01/usw/offln/bin/ulgscan";
$lgperx = "/uswsup01/usw/offln/bin/lgperx";
$rpt_join = "/uswsup01/usw/offln/bin/rpt_join";

# Name of per file
$sysfile = sprintf "per%s%s%s.lg", $month2d, $day2d, $hour2d;
$perfile = sprintf "exp%s%s%s.lg", $month2d, $day2d, $hour2d;
$DBUG && print("sysfile:$sysfile\n");
$DBUG && print("perfile:$perfile\n");

# Name of perf file
$perf_file = sprintf "perf.%s%s", $month2d, $day2d;
$DBUG && print("perf_file:$perf_file\n");

###################################
##  Forward Declare Subroutines  ##
###################################
sub copy_files;
sub read_file;
sub compute_perf;
sub update_perf;
sub logx_perf;
sub clean_up;

##########
## MAIN ##
##########
copy_files();
read_file();
logx_perf();
clean_up();

#####################################################
##  Subroutine:  copy_files                        ##
##  Copy per files from prod to sup.               ##
#####################################################

sub copy_files {
  $DBUG && print(">copy_files\n");

  # Copy per files from the uswprod servers
  for $system (@system_list) {

    # Directory where per logs are written to on $system
    $logdir = "/$system/logs/lg2";
  
    # Build command to get per file 
    $SCP_PER = sprintf "/bin/scp %s\@%s:%s/%s %s%s_%s", 
         $user, $system, $logdir, $sysfile, $workdir, $system, $perfile;
    $DBUG && print("SCP command:$SCP_PER\n");

    # Get the per file
    system $SCP_PER;

    # Build ARGS for rpt_join
    $perjn_args .= "-i $workdir${system}_$perfile ";
    $perrm_cmd .= "$workdir${system}_$perfile ";
    $DBUG && print("PER Join ARGs: $perjn_args\n");
  }

  # Run rpt_join
  $PER_JOIN = "$rpt_join $perjn_args -o $workdir$perfile > /dev/null 2> /dev/null";
  $DBUG && print("PER Join command:$PER_JOIN\n");
  system $PER_JOIN;

  $DBUG && print("<copy_files\n");
}

#####################################################
##  Subroutine:  read_file                         ##
##  Analyze the per file obtained, and update the  ##
##  perf file with the results                     ## 
#####################################################

sub read_file {
  $DBUG && print(">read_file\n");

  # Create filter file
  open FILTER, "> $workdir/filter" or
    die "Can't open $workdir/filter for writing.\n";
    print FILTER "find\nread -e\nexit\n";
    close FILTER;

  $DBUG && print("Open:$workdir/$perfile\n");

  # Create file pointer to ulgscan pipe
  open ULGSCAN, "$ulgscan -f $workdir/filter $workdir/$perfile 2> /dev/null |"
       or die "Can't create file pointer to ulgscan pipe.\n";
  
  $DBUG && print("Opened $workdir/$perfile\n");

  # Comupute performance data from the PER file
  compute_perf();

  # Close the file pointer to the ulgscan pipe
  close ULGSCAN;
  close OFP;
  $DBUG && print("Closed $workdir/$perfile\n");
  $DBUG && print("<read_file\n");
}

#####################################################
##  Subroutine:  compute_perf                      ##
##  Compute performance information from per files ##
#####################################################
sub compute_perf {

  $DBUG && print(">compute_perf\n");
  
  # Read the lines from the  pipe and handle accordingly
  while ($line = <ULGSCAN>) {

    # A new message, grab the transaction type
    if ($line =~ /^utt=.,  rqt=(.*), rpt=(.*)/) {
      $trans_type = $1;
      $resp_type = $2;
      # Keep reading lines until we match the line with the trip times.  
      until ($line =~ /^DELTA/) {
        $line = <ULGSCAN>;
	printf OFP $line;
      }

      # Grab the grt and hrt times from the line
      $line =~ /^DELTA T: grt=(\d+) hrt=(\d+)/;
      $grt = $1;
      $hrt = $2;

      # Special code for bug installed on 11/21/04 w/ CHG24395
      if ($hrt > $grt) {
	$tmp_hrt = $hrt;
	$hrt = ($tmp_hrt + 50) / 100;
      }

      # Calculate the usw dwell time
      $uswdwell = $grt - $hrt;

      # If error use Response Type
      if ($resp_type eq "ERRRP" || $resp_type eq "ERRREP") {
    
        # Set to ERRRP for consistency
        $resp_type = "ERRRP";
    
        # Count the response 
        $num{$resp_type}++;
      
        # Sum up the USW dwell time
        $rtrip{$resp_type} += $uswdwell;
      }
      else {
    
        # Count the transaction 
        $num{$trans_type}++;
      
        # Sum up the USW dwell time
        $rtrip{$trans_type} += $uswdwell;
      }
    } 
  }

  $DBUG && print("<compute_perf\n");
}

#####################################################
##  Subroutine:  logx_perf                         ##
##  Analyze the per file obtained, and update the  ##
##  perf file with the results                     ## 
#####################################################

sub logx_perf {
  $DBUG && print(">logx_perf\n");

  $DBUG && print("Opened $workdir/$perfile\n");

  system("$lgperx $workdir/$perfile");

  $DBUG && print("Closed $workdir/$perfile\n");
  $DBUG && print("<logx_perf\n");
}

#######################################################
##  Subroutine:  clean_up                            ##
##  Remove the filter file and the perf.update file  ##
#######################################################
sub clean_up {
  $DBUG && print(">clean_up\n");
  
  # Compress perfile
  $GZIP_CMD = "/bin/gzip $workdir/$perfile &";
  $DBUG && print("GZIP CMD: $GZIP_CMD\n");
  system $GZIP_CMD;

  # Build rm command
  $RM_CMD = "/bin/rm $workdir/filter $perrm_cmd";
  $DBUG && print("RM CMD: $RM_CMD\n");

  # Run rm command
  system $RM_CMD;

  $DBUG && print("<clean_up\n");
}
