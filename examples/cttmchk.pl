#!/usr/local/bin/perl
# (]$[) cttmchk.pl:1.21 | CDATE=10/16/10 17:32:13

#############################################################
##  This script will tally up the CTTMs and DSTBs from the ##
##  runtime log and send out an E-mail if the number of    ##
##  timeouts for a brand is greater than the limit.        ##
#############################################################

###########################################
##  Forward declarations of subroutines  ##
###########################################
sub parse_master;
sub parse_stdin;
sub print_to;
sub print_db;
sub mail_warning;

#########################
##  Environment setup  ##
#########################

# Turn off/on Debugging
$DBUG = 0;

# Do not buffer STDOUT output if DBUG
if ($DBUG) {
  select STDOUT; 
  $|=1;
}

# E-mail alert limit
$to_alert_limit = 100;
$db_alert_limit = 100;

# Alert iterations before staggering E-mail alerts
$to_alert_iterations = 3;
$db_alert_iterations = 3;

# Paging limit
$to_page_limit = 500;
$db_page_limit = 500;

# Location of master.cfg file
$zone = `uname -n`;
chomp $zone;
$master_config = "/$zone/prod/config/master.cfg";

# Array of GDS connections
@gdslist = qw "AA UA 1P 1A WB MS HD";

# List of GDS connections
$gdslist = join " ", @gdslist; 

# Check the time and set up some variables
@time = gmtime;
$day = $time[3] + 0;
$hour = $time[2];

$DBUG && print("Day: $day Hour:$hour\n");

# Location of outfile
$to_file = "/$zone/perf/timeouts/mike_tolog" . $day;
$DBUG && print("TO File: $to_file\n");

$db_file = "/$zone/perf/timeouts/mike_dblog" . $day;
$DBUG && print("DB File: $db_file\n");

# E-mail Recipient List
$recipients = "pedpg\@pegs.com ";

############
##  MAIN  ##
############
parse_master;
parse_stdin;
exit;

################################
##  Subroutine: parse_master  ##
################################
sub parse_master {

  # Open the master.cfg file
  open MASTER, $master_config or die "Can't open $master_config.\n";

  # Read master.cfg file
  while ($line = <MASTER>) {
   
    # Ignore blank lines and comments
    if ($line !~ /^$|^#/) {
      $hold = "";
     
      # If the line has a "\" remove the end of line and "\" and
      # concatonate with the next line.
      while ($line =~ /\\$/) {
        chomp $line;
        chop $line;
        $hold = $hold . $line;
        $line=<MASTER>;
      }
      chomp $line;
      $hold = $hold . $line;

      # Found a new config type
      if ($line =~ /{/) {
        chomp $line;
        chop $line;
        chop $line;
        $config_type = $line;
        %hold = ();
      } 

      # Found a new variable
      elsif ($line =~ / = /) {
        ($key, $value) = split / = /, $hold;
        $hold{$key} = $value;
      } 

      # End of config block, process the data
      else {

        # Set up the hrs_equi hash
        if ($config_type eq "HRS_EQUIVALENCE") {
          $hrs_equi{$hold{PRIMARY_ID}} = $hold{HRS};
        }
      }
    }
  }

  # Close master.cfg file
  close MASTER;
  
  # Create an array and a space delimited string of primary IDs
  for $hrs (sort keys %hrs_equi) {
    push @hrslist, $hrs;
    $hrslist = $hrslist . " " . $hrs;
  }
}


###############################
##  Subroutine: parse_stdin  ##
###############################
sub parse_stdin {

  # Zero out previous file unless this is a restart
  if ($hour > 0) {
    open TOLOG, ">> $to_file" or die "Can't open $to_file.\n";
    open DBLOG, ">> $db_file" or die "Can't open $db_file.\n";
  }
  else {
    open TOLOG, "> $to_file" or die "Can't open $to_file.\n";
    open DBLOG, "> $db_file" or die "Can't open $db_file.\n";
  }

  # Do not buffer TOLOG
  select TOLOG; 
  $|=1;
  printf TOLOG "Timeout page limit: $to_page_limit\n";
  printf TOLOG "Timeout E-mail alert limit: $to_alert_limit\n\n";

  # Do not buffer DBLOG
  select DBLOG; 
  $|=1;
  printf DBLOG "Destination busy page limit: $db_page_limit\n";
  printf DBLOG "Destination busy E-mail alert limit: $db_alert_limit\n\n";

  # Read in STDIN
  while ($block=<STDIN>) {
  
    # Make sure the date is good 
    #  03/10/12 00:00:01
    if ($block =~ /(\d\d)\/(\d\d)\/(\d\d) (\d\d):(\d\d):(\d\d)/) {
      next if ($day ne $2);
    }

    # Check for CTTM in the block
    if ($block =~ /CTTM/) {
      
      # Split the block to catch lines that may have run together
      @block = split /\[/, $block;
  
      # Process each line 
      for $line (@block) {
  
        # Check the line for CTTM
        if ($line =~ /CTTM/) {
          $DBUG && print("LINE:$line");
  
          # Grab the IP, HRS, and GDS involved in the timeout
          @line = split / +/, $line;
          ($junk, $hrs) = split /\:/, $line[10];
          ($junk, $gds) = split /\:/, $line[11];

          @ip = split //, $line[4];
          shift @ip;
          $hold = join "", @ip;
          ($ip, $junk) = split /-/, $hold;
          $DBUG && print("HRS:$hrs GDS:$gds IP:$ip\n");
  
          # Increment the total timeouts
          $total_to++;
  
          # If the IP matches the HRS update the hrs count
          if ($ip =~ /^$hrs/) {
            $hrs_to{$hrs}++;
          } 
          
          # IP must match GDS, so update that hash.  Also update the
          # hrsgds_to hash
          else {
            $gds_to{$gds}++;
            $hrsgds_to{$hrs}++;
          }
        }
      }
    }
    elsif ($block =~ /DSTB/) {
      
      # Split the block to catch lines that may have run together
      @block = split /\[/, $block;
  
      # Process each line 
      for $line (@block) {
  
        # Check the line for DSTB
        if ($line =~ /DSTB/) {
          $DBUG && print("LINE:$line");
  
          # Grab the IP, HRS, and GDS involved in the timeout
          @line = split / +/, $line;
          ($junk, $hrs) = split /\:/, $line[11];
          ($junk, $gds) = split /\:/, $line[12];
          @ip = split //, $line[4];
          shift @ip;
          $hold = join "", @ip;
          ($ip, $junk) = split /-/, $hold;
          $DBUG && print("HRS:$hrs GDS:$gds IP:$ip\n");

          # Increment the total destination busy
          $total_db++;
  
          # Only the HRS IP writes destination busy messages
          $hrs_db{$hrs}++;
          $gds_db{$gds}++;
          $hrsgds_db{$hrs}++;
        }
      }
    }

    # Split the block again
    @line = split / +/, $block;
   
    ($second,$minute,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);

    # Calculate the time in minutes
    $currtime = $hour * 60 + $minute;

    # Check to see if the the end of the day is upon us.
    if ($currtime > 1439) {
      print TOLOG "The day is over\n";
      print DBLOG "The day is over\n";
      last;
    } 

    # Check to see if it's time to print minute totals
    elsif ($currtime > $lasttime) {

      # Build the time variable in the event we need to send an  E-mail
      $time = sprintf "%02d:%02d", $hour, $minute; 

      # Print Context timeout and detination busy counts 
      print_to();
      print_db();

      # Reset variables for next minute
      $lasttime = $currtime;
      %hrs_to = ();
      %gds_to = ();
      %hrsgds_to = ();
      %hrs_db = ();
      %gds_db = ();
      %hrsgds_db = ();
      $total_to = 0;
      $total_db = 0;
    }
  }

  close TOLOG;
  close DBLOG;
}

############################
##  Subroutine: print_to  ##
############################
  
sub print_to {

  # Print Context timeout info for the HRSs
  for $hrs (@hrslist) {
    $DBUG && printf("TOLOG:%02d:%02d HRS=%s %d\n", 
                    $hour, $minute, $hrs, $hrs_to{$hrs});
    printf TOLOG "%02d:%02d HRS=%s %d\n", 
	   $hour, $minute, $hrs, $hrs_to{$hrs};

    # Check limit and possibly send E-mail
    if ($hrs_to{$hrs} > $to_alert_limit) {

      # Increment TO warn_count
      $to_warn_count{$hrs}++;
      $DBUG && print("TOLOG: warn count:$to_warn_count{$hrs}\n");

      # Send email if TO count is < TO iteration
      # or if TO count > page limit
      if ($hrs_to{$hrs} > $to_page_limit ||
          $to_warn_count{$hrs} < $to_alert_iterations) {
        $DBUG && print("TOLOG: Send email TO > page limit");
        mail_warning ($hrs, $time, $hrs_to{$hrs}, "timeouts");
      }

      # After reaching the TO alert iterations only send them 
      # every TO alert iterations minutes
      elsif (($to_warn_count{$hrs} % $db_alert_iterations) == 0) {
        $DBUG && print("TOLOG: Send email TO > alert limit");
        mail_warning ($hrs, $time, $hrs_to{$hrs}, "timeouts");
      }
      else {
        $DBUG && print("TOLOG: No email this time\n");
      }
    }
    
    # Timeouts below limit so reset the TO warn_count
    else {
      $to_warn_count{$hrs} = 0;
    }
  }

  # Print Context timeout info for the GDS timeouts
  for $gds (@gdslist) {
    printf TOLOG "%02d:%02d GDS=%s %d\n", 
	   $hour, $minute, $gds, $gds_to{$gds};
  }

  # Print the total timeouts
  printf TOLOG "%02d:%02d ALL-CTTM %d\n", $hour, $minute, $total_to;
}

############################
##  Subroutine: print_db  ##
############################
  
sub print_db {

  # Print Destination Busy info for the HRSs
  for $hrs (@hrslist) {
    $DBUG && printf("DBLOG:%02d:%02d HRS=%s %d\n", 
                    $hour, $minute, $hrs, $hrs_db{$hrs});
    printf DBLOG "%02d:%02d HRS=%s %d\n", 
	   $hour, $minute, $hrs, $hrs_db{$hrs};

    # Check limit and possibly send E-mail
    if ($hrs_db{$hrs} > $db_alert_limit) {

      # Increment DB warn_count
      $db_warn_count{$hrs}++;
      $DBUG && print("DBLOG: warn count:$db_warn_count{$hrs}\n");

      # Send email if DB count is < DB iteration
      # or if DB count > page limit
      if ($hrs_db{$hrs} > $db_page_limit ||
          $db_warn_count{$hrs} < $db_alert_iterations) {
        $DBUG && print("DBLOG: Send email TO > page limit");
        mail_warning ($hrs, $time, $hrs_db{$hrs}, "destination busy");
      }

      # After reaching the DB alert iterations only send them 
      # every DB alert iterations minutes
      elsif (($db_warn_count{$hrs} % $db_alert_iterations) == 0) {
        $DBUG && print("DBLOG: Send email TO > alert limit");
        mail_warning ($hrs, $time, $hrs_db{$hrs}, "destination busy");
      }
      else {
        $DBUG && print("DBLOG: No email this time\n");
      }
    }
    
    # Destination busy below limit so reset the DB warn_count
    else {
      $db_warn_count{$hrs} = 0;
    }
  }

  # Print Context timeout info for the GDS timeouts
  for $gds (@gdslist) {
    printf DBLOG "%02d:%02d GDS=%s %d\n", 
	   $hour, $minute, $gds, $gds_db{$gds};
  }

  # Print the total destiantion busy
  printf DBLOG "%02d:%02d ALL-DSTB %d\n", $hour, $minute, $total_db;
}

###################################
##  Subroutine: to_mail_warning  ##
###################################
sub mail_warning {
  
  # Set variables from subroutine args
  $hrs = $_[0];
  $time = $_[1];
  $num = $_[2];
  $type = $_[3];

  # Build mail command
  $MAIL_TXT = sprintf "%s had %s %s at %s", 
                       $hrs, $num, $type, $time;
  $MAIL_CMD = sprintf "/bin/mailx -s \"%s\" %s < /dev/null", 
		      $MAIL_TXT, $recipients;
 
  # Send it!
  system $MAIL_CMD;
}
