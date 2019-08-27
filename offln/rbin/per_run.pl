#!/usr/local/bin/perl
# (]$[) hour_perf.pl:1.15 | CDATE=12/07/12 22:17:05
#
# Grab the per logs from uswprod01-04, join them into a single file,
# analyze it, and move the output to uswprod01
use Time::Local;

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

# Make it GMT time
$ENV{TZ} = "UTC";

# DBUG On/Off
$DBUG = 0;

# User to connect with
$user = "usw";

# Directory on $system where perf files are located
$perfdir = "/uswprod01/perf/daily";

# Systems to pull per logs from
@system_list = qw ( uswprod01 uswprod02 uswprod03 uswprod04 );

# Directory where work is done
$workdir = "/uswsup01/loghist/per_all/";
$sumdir = "/uswsup01/research/per_sum/";
$DBUG && print("workdir:$workdir sumdir: $sumdir\n");

chdir $workdir;

# Full path to ulgscan / rpt_join
$lgscan = "/uswsup01/usw/offln/bin/lgscan";
$rpt_join = "/uswsup01/usw/offln/bin/rpt_join";

$perfile_main = sprintf "per%s%s%s.lg", $month2d, $day2d, $hour2d;
$sumfile = sprintf "per%s%s%s.sum", $month2d, $day2d, $hour2d;

# Name of perf file
$perfoutput = sprintf "perf.%s%s", $month2d, $day2d;
$DBUG && print("perfoutput:$perfoutput\n");

###################################
##  Forward Declare Subroutines  ##
###################################
sub copy_files;
sub read_file;
sub compute_perf;
sub update_perf;
sub clean_up;

##########
## MAIN ##
##########
copy_files();
read_file();
update_perf();
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
    $logdir = "/${system}/logs/lg2";
  
    # Build command to get per file 
    $SCP_PER = sprintf "/bin/scp %s\@%s:%s/%s %s%s_%s", 
	 $user, $system, $logdir, $perfile_main, $workdir, $system,
	 $perfile_main;
    $DBUG && print("SCP command:$SCP_PER\n");

    # Get the per file
    $status = system $SCP_PER;

    if ($status == 0) {
      # Build ARGS for rpt_join
      $perjn_args .= "-i ${workdir}${system}_$perfile_main ";
      $perrm_cmd .= "${workdir}${system}_$perfile_main ";
      $DBUG && print("PER Join ARGs: $perjn_args\n");
    }
  }

  $redir = " > /dev/null 2> /dev/null";
  # Run rpt_join
  $PER_JOIN = "$rpt_join $perjn_args -o $workdir$perfile_main $redir";
  $DBUG && print("PER Join command:$PER_JOIN\n");
  system $PER_JOIN;

  @perf_files = qx(ls -1 $workdir$perfile_main*);

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

  # Iterate through the per files for this hour.
  foreach $perfile (@perf_files) {
    chomp $perfile;

    $DBUG && print("Open: $perfile \n");

    $lgpipe = sprintf "%s -f %sfilter %s 2> /dev/null |", $lgscan, $workdir,
       $perfile;
    $DBUG && print("lgpipe is $lgpipe \n");
    # Create file pointer to lgscan pipe
    open LGSCAN, "$lgpipe" or die "Can't create file pointer to lgscan pipe.\n";
    
    open LGSUM, ">> ${sumdir}${sumfile}" or die "can't open sum\n";

    $DBUG && print("Opened $perfile\n");
    $DBUG && print("Opened $sumdir$sumfile\n");

    # Comupute performance data from the PER file
    compute_perf();

    # Close the file pointer to the lgscan pipe
    close LGSCAN;
    $DBUG && print("Closed $workdir/$perfile\n");

  }   
  close LGSUM;
  $DBUG && print("<read_file\n");
}

#####################################################
##  Subroutine:  compute_perf                      ##
##  Compute performance information from per files ##
#####################################################
sub compute_perf {

  $DBUG && print(">compute_perf\n");
  
  # Read the lines from the  pipe and handle accordingly
  while ($line = <LGSCAN>) {
    $DBUG && print("LINE =\n$line");

    # example: File pointer 0x318d, time stamp 03/05/13 17:00:02
    if ($line =~ /^File pointer/) {
      
      # get time stamp from "03/05/13 17:00:02"
      $line =~ /(\d\d)\/(\d\d)\/(\d\d) (\d\d):(\d\d):(\d\d)/;
      $utc = timegm($6, $5, $4, $2, $1-1, $3);

      # Reset all vars to 0
      $hrs, $gds, $utt, $sum_msn, $trans_type, $resp_type = "";
      $tmo, $trt, $hrt, $grt = 0;

    }
    # example: LGPER|GDSWB|HRSEO|MSN1204136249174D|RQTPALSRQ|RPTPALSRP|...
    elsif ($line =~ /^LGPER/) {
      
      # Put in a place holder and save off this line.  Get rid of the '\' on 
      # the end.
      chomp $line;
      $last_char = chop $line;
      $whole_perline = $line;

      if ($last_char eq '\\') {
	# L152|GOL647|HIL572|HOL155|GRT3|HRT1|TRQ4||\00

	$line = <LGSCAN>;
	chomp $line;
	$whole_perline .= $line;
      }

      if ($whole_perline =~ /\|HRS(\w+)\|/) {
        $hrs = $1;
      }
      if ($whole_perline =~ /\|GDS(\w+)\|/) {
        $gds = $1;
      }
      if ($whole_perline =~ /\|UTT(\w)\|/) {
        $utt = $1;
      }
      if ($whole_perline =~ /\|MSN(\w+)\|/) {
        $sum_msn = $1;
      }
      if ($whole_perline =~ /\|RQT(\w+)\|/) {
        $trans_type = $1;
      }
      if ($whole_perline =~ /\|RPT(\w+)\|/) {
        $resp_type = $1;
      }
      if ($whole_perline =~ /\|TMO(\w)\|/) {
        $tmo = $1;
      }
      if ($whole_perline =~ /\|TRT(\d+)\|/) {
        $trt = $1;
      }
      else {
        $trt = 0;
      }
      if ($whole_perline =~ /\|HRT(\d+)\|/) {
        $hrt = $1;
      }
      if ($whole_perline =~ /\|GRT(\d+)\|/) {
        $grt = $1;
      }

      # TMO values are G or D so if it's G make it 1, if D make it 2.
      if ($tmo eq 'G') {
        $sum_tmo = 1;
      }
      elsif ($tmo eq 'D') {
        $sum_tmo = 2;
      }
      else {
        $sum_tmo = 0;
      }

      # TRT is a short int, so prune if bigger then 100
      if ($trt > 100) {
        $trt = 100;
      }

      # MSN isn't right so ignore.
      $dec_tstamp = 0;

      # Change the GDS for RTYUPs and PRINUPS to "us" 
      if (!($gds) && 
	  ($trans_type eq "RTYUP" ||
	   $trans_type eq "PRSDUP" ||
	   $trans_type eq "GRINUP" ||
	   $trans_type eq "NRATUP" ||
	   $trans_type eq "PRINUP")) {
	$sum_gds = "us";
      }
      else {
	# Make GDS just first two chars
	@tmp_gds = split (//, $gds);
	$sum_gds = $tmp_gds[0] . $tmp_gds[1];
      }

      # Take the first 4 chars of RPT
      @tmp_rsp = split (//, $resp_type);
      @tsumrpt = splice(@tmp_rsp, 0, 4);
      $sum_rpt = join("", @tsumrpt);

      # Print out record, it's just
      printf LGSUM "%d|%s|%s|%d|%s|%d|%d|%d|%s\n", $utc, $sum_gds, $hrs, 
        $trt, $dec_tstamp, $sum_tmo, $hrt != 0 ? $hrt : "", 
        $grt != 0 ? $grt : "", $sum_rpt;

      # Special code for bug installed on 11/21/04 w/ CHG24395
      if ($hrt > $grt) {
	$hrt = ($hrt + 50) / 100;
      }

      # Calculate the usw dwell time
      $uswdwell = $grt - $hrt;

      # Only collect for a subset of data.
      if (($resp_type eq "ERRRP" && $utt eq "A") ||
          ($resp_type eq "ERRREP" && $utt eq "A")) {

        # Set to ERRRP for consistency
        $resp_type = "ERRRP";

        # Count the response 
        $num{$resp_type}++;

        # Sum up the USW dwell time
        $rtrip{$resp_type} += $uswdwell;
      }
      elsif (($trans_type eq "PALSRQ" && $resp_type eq "PALSRP") ||
             ($trans_type eq "RPINRQ" && $resp_type eq "RPINRP") ||
             ($trans_type eq "RPINRQ" && $resp_type eq "PRINRP") ||
             ($trans_type eq "BOOKRQ" && $resp_type eq "BOOKRP") ||
             ($trans_type eq "AVSTAT" && $resp_type eq "AVSTAT") ||
             ($trans_type eq "AALSRQ" && $resp_type eq "AALSRP") ||
             ($trans_type eq "PRSDUP" && $resp_type eq "PRSDUP") ||
             ($trans_type eq "PRINUP")) {

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
##  Subroutine:  update_perf                       ##
##  Update daily perf file w/ computed data        ##
#####################################################
sub update_perf {

  $DBUG && print(">update_perf\n");

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
  $DBUG && system("cat $workdir/perf.update");

  # Update the perf file in production
  $UPDATE_PERF = sprintf "/bin/ssh %s@%s \"cat >> %s/%s\" < %s/perf.update",
     $user, "uswprod01", $perfdir, $perfoutput, $workdir;
  $DBUG && print("UPDATE PERF: $UPDATE_PERF\n");
  system $UPDATE_PERF;

  $DBUG && print("<update_perf\n");
}

#######################################################
##  Subroutine:  clean_up                            ##
##  Remove the filter file and the perf.update file  ##
#######################################################
sub clean_up {
  $DBUG && print(">clean_up\n");
  
  # Compress perfile
  $GZIP_CMD = "/bin/gzip $workdir$perfile_main* &";
  $DBUG && print("GZIP CMD: $GZIP_CMD\n");
  system $GZIP_CMD;
 
  # Compress sumfile
  $GZIP_CMD = "/bin/gzip $sumdir$sumfile &";
  $DBUG && print("GZIP CMD: $GZIP_CMD\n");
  system $GZIP_CMD;
  
  # Build rm command
  #$RM_CMD = "/bin/rm -f ${workdir}filter ${workdir}perf.update $perrm_cmd";
  $RM_CMD = "/bin/rm -f ${workdir}filter $perrm_cmd";
  $DBUG && print("RM CMD: $RM_CMD\n");

  # Run rm command
  system $RM_CMD;

  $DBUG && print("<clean_up\n");
}
