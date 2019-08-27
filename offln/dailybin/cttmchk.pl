#!/usr/local/bin/perl
############################################################
##  This script will tally up the CTTMs from the runtime  ##
##  log and send out an E-mail if the number of timeouts  ##
##  for a brand is greater than the threshold.            ##
############################################################

###########################################
##  Forward declarations of subroutines  ##
###########################################
sub parse_master;
sub parse_stdin;
sub mail_warning;

#########################
##  Environment setup  ##
#########################

# Location of master.cfg file
$master_config="/prod/config/master.cfg";

# Array of GDS connections
@gdslist = qw "AA UA 1P 1A WB MS HD";

# List of GDS connections
$gdslist = join " ", @gdslist; 

# Check the time and set up some variables
@time = gmtime;
$day = $time[3] + 0;

# Location of outfile
$timeoutfile = "/prod/perf/timeouts/tolog_test" . $day;

# Recipient List
$recipients = "vladimir.frisby\@pegs.com";

############
##  MAIN  ##
############
parse_master;
parse_stdin;

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
  # Be lazy and use the STDOUT file pointer
  close STDOUT;
  open STDOUT, "> $timeoutfile" or die "Can't open $timeoutfile.\n";
  select STDOUT; 
  $|=1;
  
  # Read in STDIN
  while ($block=<STDIN>) {
  
    # Check for CTTM in the block
    if ($block =~ /CTTM/) {
      
      # Split the block to catch lines that may have run together
      @block = split /\[/, $block;
  
      # Process each line 
      for $line (@block) {
  
        # Check the line for CTTM
        if ($line =~ /CTTM/) {
  
          # Grab the IP, HRS, and GDS involved in the timeout
          @line = split / +/, $line;
          ($junk, $hrs) = split /\:/, $line[10];
          ($junk, $gds) = split /\:/, $line[11];
          @ip = split //, $line[4];
          shift @ip;
          $hold = join "", @ip;
          ($ip, $junk) = split /-/, $hold;
  
          # Increment the total timeouts
          $total++;
  
          # If the IP matches the HRS upate the hrs count
          if ($ip =~ /^$hrs/) {
            $hrsto{$hrs}++;
          } 
          
          # IP must match GDS, so update that hash
          else {
            $gdsto{$gds}++;
          }
        }
      }
    }

    # Split the block again
    @line = split / +/, $block;
   
    # If the third field matches the time format split it
    if ($line[2] =~ /\d\d\:\d\d\:\d\d/) {
      ($hour, $minute, $second) = split /\:/, $line[2];
    } 

    # Check to see if the fourth element matches the time
    elsif ($line[3] =~ /\d\d\:\d\d\:\d\d/) {
      ($hour, $minute, $second) = split /\:/, $line[3];
    }

    # Calculate the time in minutes
    $currtime = $hour * 60 + $minute;

    # Check to see if the the end of the day is upon us.
    if ($currtime > 1435) {
      print "The day is over\n";
      exit;
    } 
    
    # Check to see if the next minute is upon us
    elsif ($currtime > $lasttime) {

      # Print Context timeout info for the HRS timeouts
      for $hrs (@hrslist) {
        printf "%02d:%02d HRS=%s %d\n", $hour, $minute, $hrs, $hrsto{$hrs};

        # Check threshold and send E-mail
        if ($hrsto{$hrs} > 20) {

          # Increment warn_count
          $warn_count{$hrs}++;

          # Build the time variable in the event we need to send an  E-mail
          $time = sprintf "%02d:%02d", $hour, $minute; 

          # If this is in the first 5 iteratations send an E-mail
          if ($warn_count{$hrs} < 5) {
            mail_warning ($hrs, $time, $hrsto{$hrs});
          } 

          # After the first 5 send them every 5 minutes
          elsif (($warn_count{$hrs} % 5) == 0) {
            mail_warning ($hrs, $time, $hrsto{$hrs});
          }
        } 
    
        # Timeouts below threshold so reset the warn_count
        else {
          $warn_count{$hrs} = 0;
        }
      }

      # Print Context timeout info for the GDS timeouts
      for $gds (@gdslist) {
        printf "%02d:%02d GDS=%s %d\n", $hour, $minute, $gds, $gdsto{$gds};
      }

      # Print the total timeouts
      printf "%02d:%02d ALL-CTTM %d\n", $hour, $minute, $total;

      # Reset variables for next minute
      $lasttime = $currtime;
      $total = 0;
      %hrsto = ();
      %gdsto = ();
    }
  }
}

################################
##  Subroutine: mail_warning  ##
################################
sub mail_warning {
  
  # Set variables from subroutine args
  $hrs = $_[0];
  $time = $_[1];
  $num = $_[2];

  # Build mail command
  $MAIL_CMD = sprintf 
       "/usr/bin/mailx -s \"%s had %s timeouts at %s\" %s < /dev/null", 
       $hrs, $num, $time, $recipients;
 
  # Send it!
  system $MAIL_CMD;
}
