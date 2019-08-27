#!/usr/local/bin/perl
##
## (]$[) dt_tally.pl:1.31 | CDATE=01/22/13 05:17:50
##                                                        
##                                                        
##             Copyright (C) 1999 Pegasus Systems, Inc.   
##                  All Rights Reserved                   
##                                                        
##
##  A rewrite of the "backawk" process that counts the downtime from 
##  the runtime log.  Loads the data into a database and dumps the output
##  standard out.  A "outlier" report is also sent that contains a list of
##  severe outages.

$zone = `uname -n`;
chomp $zone;
$zone_informixserver = $zone . "_1";
$zone_informixdir = "/informix-" . $zone . "_1";

#*SUBTTL Includes, dedined parameters, and common storage
require "/$zone/usw/offln/bin/fish.pl";

DBUG_FILE("dt_tally.djunk");
#VLAD - Comment out the debug piece
#DBUG_ON();

###################################
## Forward declare sub routines  ##
###################################
sub setup_environment;
sub set_defaults;
sub usage;
sub parse_command_line;
sub parse_statsub;
sub load_still_downs;
sub locate_IPs;
sub output_outages;
sub set_connection_down;
sub set_connection_up;
sub pre_output_processing;
sub load_into_db;
sub parse_rtlog;
sub mail_outlier;
sub calc_time_diff;

##
##SUBTTL main
##                                                        
## Parses runtime log building a list of outages, and    
## depending on the options either loads this into a      
## database or outputs to STDOUT                          
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

DBUG_ENTER("main");

set_defaults();
parse_command_line();
parse_statsub();
locate_IPs();
setup_environment();
parse_rtlog();
pre_output_processing();
load_into_db();
output_outages();
send_outliers();

#This function doesn't actually return - just prints something
DBUG_VOID_RETURN();

##
##SUBTTL setup_environment 
##                                                        
## Prepare environment 
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub setup_environment {

  DBUG_ENTER("setup_environment");

  # Set up informix variables
  $ENV{INFORMIXSERVER} = "$zone_informixserver";
  $ENV{INFORMIXDIR} = "$zone_informixdir";
  $ENV{INFORMIXSQLHOSTS} = "$zone_informixdir/etc/sqlhosts.$zone_informixserver";

  # Using the date calculate the base value for the decimal UTC 
  $date_d = `/$zone/usw/offln/bin/tstamp -t $date -od`;
  chomp $date_d;
  
  # Open DBACCESS pipe
  open DBACCESS, "| $zone_informixdir/bin/dbaccess usw_perf";

  DBUG_PRINT("setup_environment", "deleting data for %s from downtime", $date);
  DBUG_PRINT("setup_environment", "  ddate = %s", $date_d);

  # Tell Informix to delete some stuff
  printf DBACCESS "delete from downtime where time_d >= %d and time_d < %d\n",
         $date_d, ($date_d + 86400);

  close DBACCESS;

  # Open rtlog file or fail
  open RTLOG, $rtlogfile or 
       open RTLOG, "gunzip -c $rtlogfile |" or 
       die "Can't open $rtlogfile for reading.\n";

  DBUG_PRINT("setup_environmet", "Opening RTLOG with %s", $rtlogfile);

  # Open output file or fail
  open OUTPUT, "> $outputfile" or die "Can't open $outputfile for writing.\n";

  DBUG_PRINT("setup_environmet", "Opening OUTPUT with %s", $outputfile);

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL set_defaults 
##                                                        
## Defaults variables that can potencially be over ridden 
## with command line options
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub set_defaults {

  DBUG_ENTER("set_defaults");
  
  # Set the default date to previous day
  $date = `/$zone/usw/offln/bin/getydate -s`;

  # Split date into individual variables and build monthdir
  ($month, $day, $year) = split /\//, $date;
  $monthdir = sprintf "%02d%02d", $month, $year;
   
  # Root directory of rtlogs
  $rtlog_rootdir = "/$zone/loghist/uswsd01/rtlogs";

  # Build rtlogfile
  $rtlogfile = sprintf "%s/%s/rtlog%d", $rtlog_rootdir, $monthdir, $day;
 
  # Root directory of awklogs
  $awklog_rootdir = "/$zone/loghist/uswprod01/awklogs";

  # Make sure the month subdirectory exists
  if (-e $awklog_rootdir/$monthdir) {
    DBUG_PRINT("set_defaults", ("%s/%s exists", $awklog_rootdir, $monthdir));
  }
  else {
    `mkdir $awklog_rootdir/$monthdir`
  }

  # Default output file 
  $outputfile = sprintf "%s/%s/awklog20%02d%02d%02d", $awklog_rootdir,
       $monthdir, $year, $month, $day;

  # Full path for statsub.cfg file
  $statsubfile = "/$zone/loghist/uswprod01/statsub/statsub.cfg";
  
  # Tmp file for outlier mail
  $outlierfile = sprintf "/tmp/outliers.%d", $$;

  # Default distribution list for outlier E-mail
  $dist_list = 'pedpg@pegs.com';

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL usage
##                                                        
## What to do when we hit a FATAL error
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub usage {

  DBUG_ENTER("usage");

  # If an arguement was given to usage print it as error output
  if ($_[0]) {
    print STDERR $_[0];
  }

  # Print usage statement
  print STDERR "usage:  dt_tally.pl\n";
  exit;
  
  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL parse_command_line 
##                                                        
## Parse command line options and make appropriate changes to
## the running environment
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub parse_command_line {

  DBUG_ENTER("parse_command_line");

  # Default to if optind if effectivly "null"
  $optind = "NO IND";

  # Loop through ARGV array to build opts hash
  for $arg (@ARGV) {

    # If there is a "-" in the front of the arg, then we have found a new 
    # option
    if ($arg =~ /^-(.*)/) {
      $optind = $1;
    } 

    # Otherwise assume that this is an arguement to a previous option
    else {
    
      # If optind is "NO IND" there is a format error in the first arg
      if ($optind ne "NO IND") {
        push @{$opts{$optind}}, $arg;
      } 

      # Bad option
      else {
        usage ("Invalid option\n");
      }
    }
  }

  # Set variables based on options found on command line.  Any variable
  # modified by the -d option needs to have its override option be
  # greater that "d"
  for $optind (sort keys %opts) {

    # Use date specified on the command line
    if ($optind eq "d") {

      # Check for date in the format of MM/DD/YY 
      if ($opts{$optind}[0] =~ /^(\d\d)\/(\d\d)\/(\d\d)$/) {
        $month = $1;
        $day = $2;
        $year = $3;  
        $date = $opts{$optind}[0];
        $monthdir = sprintf "%02d%02d", $month, $year;
        $rtlogfile = sprintf "%s/%s/rtlog%d", $rtlog_rootdir, $monthdir, $day;
        $outputfile = sprintf "%s/%s/awklog20%02d%02d%02d", $awklog_rootdir,
             $monthdir, $year, $month, $day;
      }
      else {
        usage("Invalid date format\n");
      }
    }

    # Use rtlog file specified on command line
    elsif ($optind eq "f") {
      $rtlogfile = $opts{$optind}[0];
    }
    
    # Use statsub.cfg file specified on command line
    elsif ($optind eq "o") {
      $outputfile = $opts{$optind}[0];
    }
    
    # Use statsub.cfg file specified on command line
    elsif ($optind eq "s") {
      $statsubfile = $opts{$optind}[0];
    }
    
    # Invalid option 
    else {
      usage("Invalid option: -$optind\n");
    }
  }

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL parse_statsub 
##                                                        
## Parse statsub.cfg and grab info we need
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub parse_statsub {

  DBUG_ENTER("parse_statsub");

  # Parse statsub.cfg from source
  open STATSUB, $statsubfile or die "Can't open statsub.cfg.\n";

  while ($line=<STATSUB>) {
    next if ($line =~ /^$|^#|^0_0_NCD|NCDV|^0_2_NCD|^0_33_NCD|^0_44_NCD|NCDV|GATE/);
    DBUG_PRINT("parse_statsub", "line '%s'", $line);
    if ($line =~ /TCPSES/) {
      if ($line =~ /Child/) {
        $count++;
        @line = split /\//, $line;
        @node = split /_/, $line[0];
        $node = $node[1];
        $ce_name{$node} = $line[1];
        
        DBUG_PRINT("parse_statsub", "%s = %s", "\$node", $node);
        DBUG_PRINT("parse_statsub", "%s = %s", "line0", $line[0]);
        DBUG_PRINT("parse_statsub", "%s = %s", "line1", $line[1]);
      }
    }
    elsif ($line !~ /Parent/) {
      $line =~ /^0_(\d+)_NCD\!(.*)\/.*\/.*\/.*$/;
      $node = $1;
      $ent = $2;
      if ($ent =~ /QS/) {
        ($junk, $ent) = split /:/, $ent;
      }
      $iplocation{$ent} = $node;
      if ($ent =~ /_/) {
        ($ip, $junk)  = split /_/, $ent;
      }
      else {
        @ip = split /-/, $ent;
        $ip = sprintf "%s-%s", $ip[0], $ip[1];
      }

      $comm_list_by_ent{$ent}{USWPROD01} = UP;
      $comm_list_by_ent{$ent}{USWPROD02} = UP;
      $comm_list_by_ent{$ent}{USWPROD03} = UP;
      $comm_list_by_ent{$ent}{USWPROD04} = UP;
      push @{$ent_list_by_ip{$ip}}, $ent;
      DBUG_PRINT("parse_statsub", "%s = %s", "\$ent", $ent);
      DBUG_PRINT("parse_statsub", "%s = %s", "\$node", $node);
      DBUG_PRINT("parse_statsub", "%s = %s", "\$ip", $ip);
      DBUG_PRINT("parse_statsub", "%s = %s", "\$iplocation{\$ent}", 
                  $iplocation{$ent});
    }
  }
  close STATSUB;

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL load_still_downs
##                                                        
## Check for connections that were down at end of day
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub load_still_downs {
  
  DBUG_ENTER("load_still_downs");

  open STILL;
  
  while ($line=<STILL>) {
    chomp $line;
    $found = "FALSE";
    for $comm_engine (sort keys %iploc) {
      for $ip (@{$iploc{$comm_engine}}) {
        if ($ip eq $line) {
          DBUG_PRINT("load_still_downs", "Setting %s down", $ip);
          set_connection_down ($ip, "00:00:00", "IP");
          $found = "TRUE";
        }
      }
    }
    if ($found eq "FALSE") {
      DBUG_PRINT("load_still_downs", "%s no longer in statsub.cfg", $ip);
    } 
  }
  close STILL;

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL locate_IPs 
##                                                        
## Build a hash of arrays where the key is the comm engine name
## and the array is a list of IPs/Ents on that system
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub locate_IPs {

  DBUG_ENTER("locate_IPs");

  for $ip (sort keys %iplocation) {
    push @{$iploc{$ce_name{$iplocation{$ip}}}}, $ip;
  }

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL output_outages 
##                                                        
## Output the outages 
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub output_outages {

  DBUG_ENTER("output_outages");

  # Loop through all the outages
  for $outage (@outages) {

    # Each outage is stored in a string that is "time down"|"time up"|"IP"
    @line = split /\|/, $outage;
    $line[0] =~ /(\d+:\d+:\d+)/;
    $time_down = $1;
    $line[1] =~ /(\d+:\d+:\d+)/;
    $time_up = $1;

    # Covert the time down to the number of seconds since the new day
    $time_down =~ /(\d+):(\d+):(\d+)/;
    $dtime_down = $1 * 3600 + $2 * 60 + $3;
  
    # convert the time up to the number of seconds since the new day
    $time_up =~ /(\d+):(\d+):(\d+)/;
    $dtime_up = $1 * 3600 + $2 * 60 + $3;
  
    # Calculate the number of seconds down.
    $seconds_down = $dtime_up - $dtime_down;
    
    # Calculate the number of minutes the connection was down.
    $minutes_down = $seconds_down / 60;
    
    # If we are into 10 seconds into the next minute, round it up
    if (($seconds_down % 60) > 9) {
      $minutes_down++;
    }
      
    # Print the time down, time up, ip, and minutes down
    printf OUTPUT "%s %s %s %6s TD=%d\n", 
         $date, $time_down, $time_up, $line[2], $minutes_down;

    DBUG_PRINT("ouput_outages", "%s %s - %s mins: %d", 
               $line[2], $time_down, $tiime_up, $minutes_down);
  }

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL set_connection_down 
##                                                        
## Set a connection down
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub set_connection_down {

  DBUG_ENTER("set_connection_down");
  
  # Grab two variables from function arguments
  my ($ip, $time_down, $reason) = @_;

  DBUG_PRINT("set_connection_down", "Downing %s at %s reason: %s", 
       $ip, $time_down, $reason);

  # If there was a previous outage for this IP check to see if the up
  # time is within 5 seconds of this downtime.
  if ($curr_outages{$ip} ne "") {

    # Get uptime of last outage
    ($old_down, $old_up) = split /\|/, $curr_outages{$ip};

    # If this downtime is past 5 seconds of the last uptime,
    # then process this downtime
    if (calc_time_diff($old_up, $time_down) < 5) {
      $currently_down{$ip} = sprintf "%s|%s", $old_down, $reason;
      delete $curr_outages{$ip};
      DBUG_PRINT("set_connection_down", 
           "Continue outage old up: %s time down: %s",
           $old_up, $time_down);
      #This function doesn't actually return - just prints something
      DBUG_VOID_RETURN();
    }
  }

  # If hash that contains the list of currently down connections is 
  # empty for the IP in question, update hash with downtime, otherwise
  # report that connection was reported down twice. 
  if ($currently_down{$ip} eq "") {
    $currently_down{$ip} = sprintf "%s|%s", $time_down, $reason;
    DBUG_PRINT("set_connection_down", "%s down at %s reason: %s", 
               $ip, $time_down, $reason);
  } else {
    ($curr_down, $reason_down) = split /\|/, $currently_down{$ip};
    DBUG_PRINT("set_connection_down", "%s already down at %s reason: %s", 
               $ip, $curr_down, $reason_down);
  }

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}


##
##SUBTTL set_connection_up 
##                                                        
## Set a connection up
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub set_connection_up {

  DBUG_ENTER("set_connection_up");

  # Grab variables from function arguments
  my ($ip, $time_up, $reason) = @_;

  DBUG_PRINT("set_connection_up", "Uping %s at %s reason: %s", 
       $ip, $time_up, $reason);

  # Make sure this ent was in statsub.cfg, to avoid false up/down records
  $notfound = 1;
  foreach $tmpip (keys %ent_list_by_ip) {
    for $entity (@{$ent_list_by_ip{$tmpip}}) {
      if ($ip eq $entity) {
         DBUG_PRINT("set_connection_up", ("found $ip == $entity"));
        $notfound = 0;
      }
    }
  }
  if ($notfound) {
    DBUG_PRINT("set_connection_up", ("Didn't find $ip"));
    #This function doesn't actually return - just prints something
    DBUG_VOID_RETURN();
    return;
  }

  # Get uptime of last outage
  ($old_down, $old_up) = split /\|/, $curr_outages{$ip};

  # If we have a downtime process normally
  if ($currently_down{$ip} ne "") {
  
    # Split downtime and reason
    ($curr_down, $reason_down) = split /\|/, $currently_down{$ip};
    
    # If the last up time is within the downtime, update last outage with 
    # new up time
    # If $old_up == "", then there wasn't a previous downtime
    if (("" ne $old_up) && (calc_time_diff($old_up, $curr_down) < 5)) {
      $curr_outages{$ip} = sprintf "%s|%s", $old_down, $time_up;
      DBUG_PRINT("set_connection_up", 
           "%s already upped -  down: %s up: %s new_up %s",
           $ip, $old_down, $old_up, $time_up);
    }
    else {

      if (($reason eq "IP") || ($reason eq $reason_down)) {
      
        # If the outage hash has data for the IP, load that outage into the
        # outage array
        if ($curr_outages{$ip} ne "") {
        
          push @outages, sprintf "%s|%s|%s", 
               $old_down, $old_up, $ip;
          DBUG_PRINT("set_connection_up", "%s added to ARRAY down: %s up: %s", 
                     $ip, $old_down, $old_up);
        }
        DBUG_PRINT("set_connection_up", "%s added to HASH down: %s up: %s", 
                   $ip, $curr_down, $time_up);

        # Load outage times into outage hash
        $curr_outages{$ip} = sprintf "%s|%s", 
           $curr_down, $time_up;

        # Remove downtime from currently_down hash
        #$currently_down{$ip} = "";
        delete $currently_down{$ip};
      }
    }
  } 

  # If we don't have a downtime handle with care
  else {
    
    # If we already reported this IP up, dump an error message 
    if ($last_up{$ip} ne "") {
      DBUG_PRINT("set_connection_up", 
                 ("%s has no downtime and was already reported up at %s", 
                   $ip, $last_up{$ip}));
    }  
    
    # Set downtime to top of the day (00:00:00), update the outages array,
    # as well as the last_up hash
    else {

      # Update outages hash
      $curr_outages{$ip} = sprintf "%s|%s",
           "00:00:00", $time_up;
      DBUG_PRINT("set_connection_up", "%s added to HASH down: %s up: %s", 
                 $ip, "00:00:00",  $time_up);
    }
  }

  # Update last_up 
  $last_up{$ip} = $time_up;

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL pre_outout_processing 
##                                                        
## Do some stuff before outputing outages
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub pre_output_processing {

  DBUG_ENTER("pre_output_processing");

  # Loop though currently down hash and set all the connections up at 23:59:59
  for $ip (keys %currently_down) {
    if ($currently_down{$ip} ne "") {
      DBUG_PRINT("pre_output_processing", "%s STILL down", $ip);
      set_connection_up ($ip, "23:59:59", "IP");
    }
  }

  # Loop though outages hash and load them into the array
  for $ip (keys %curr_outages) {
    if ($ip ne "") {
      ($time_down, $time_up) = split /\|/, $curr_outages{$ip};
      push @outages, sprintf "%s|%s|%s", $time_down, $time_up, $ip;
    }
  }
  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL load_into_db 
##                                                        
## Load downtime in a database
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub load_into_db {

  DBUG_ENTER("load_into_db");

  # Using the date calculate the base value for the decimal UTC 
  $date_d = `/$zone/usw/offln/bin/tstamp -t $date -od`;

  # Open temp load file
  open LOAD, "> /tmp/downtime.$$" or die "Can't open load file for writing.\n";
  
  # Create load file
  for $outage (@outages) {
    
    # Break out data from outage line
    ($time_down, $time_up, $ip) = split /\|/, $outage;
    
    # Calculate the decimal UTC values for the down and up times
    ($dh, $dm, $ds) = split /:/, $time_down;
    $time_down_d = $date_d + (3600 * $dh) + (60 * $dm) + $ds;
    ($uh, $um, $us) = split /:/, $time_up;
    $time_up_d = $date_d + (3600 * $uh) + (60 * $um) + $us;
 
    printf LOAD "%s|%s|%s|||\n", $time_down_d, $time_up_d, $ip; 
  }
 
  # Close LOAD file
  close LOAD;

  # Open DBACCESS pipe
  open DBACCESS, "| $zone_informixdir/bin/dbaccess usw_perf";
  
  # Load file into database
  printf DBACCESS "load from /tmp/downtime.%s\n", $$;
  print DBACCESS "insert into downtime\n";
  
  # Close DBACCESS pipe
  close DBACCESS;
 
  # Remove LOAD file
  `/bin/rm /tmp/downtime.$$`;

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL parse_rtlog 
##                                                        
## Parse the runtime log and determine outages
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub parse_rtlog {

  DBUG_ENTER("parse_rtlog");

  # Read the next block and split at "<="
  while ($block=<RTLOG>) {
    $line_num++;

    @block = split /=> /, $block;
    for $line (@block) {
      
      # Get the date/time from the log in the event that we need it
      $line =~ /<= (\d+\/\d+\/\d+) (\d+:\d+:\d+)/;
      $log_date = $1;
      $log_time = $2;

      # Process line
      if ($line =~ /A3IPENDN/) {
        $line =~ /IPENDN\): (.+) is/;
        $ent = $1;
        set_connection_down ($ent, $log_time, "IP");
      }
      elsif ($line =~ /A3IPENUP/) {
        $line =~ /IPENUP\): (.+) is/;
        $ent = $1;
        set_connection_up ($ent, $log_time, "IP");
      }
      elsif ($line =~ /B2IPENDN/) {
        $line =~ /IPENDN\): .+,(.+) is/;
        $ent = $1;
        set_connection_down ($ent, $log_time, "IP");
      }
      elsif ($line =~ /B2IPENUP/) {
        $line =~ /IPENUP\): .+,(.+) is/;
        $ent = $1;
        set_connection_up ($ent, $log_time, "IP");
      }
      elsif ($line =~ /ATRPDISC/) {
        $line =~ /ATRPDISC\): (.+) has/;
        $ip = $1;
        $line =~ /\[([A-Z|0-9]*)\] /;
        $tpe = $1;
        for $ent (@{$ent_list_by_ip{$ip}}) {
          #Need to set_connection_down if is now DOWN on all 3 TPEs
          # Unless it was already down on this TPE - if so, do nothing
          if (UP eq $comm_list_by_ent{$ent}{$tpe}) {
            $comm_list_by_ent{$ent}{$tpe} = DOWN;

            # This would be if setting $tpe down makes them all down
            if (DOWN eq $comm_list_by_ent{$ent}{USWPROD01} &&
                DOWN eq $comm_list_by_ent{$ent}{USWPROD02} &&
                DOWN eq $comm_list_by_ent{$ent}{USWPROD03} &&
                DOWN eq $comm_list_by_ent{$ent}{USWPROD04}) {
              set_connection_down ($ent, $log_time, "IP");
            }
          }
        }
      }
      elsif ($line =~ /ATRPIPUP/) {
        $line =~ /ATRPIPUP\): (.+) has/;
        $ip = $1;
        $line =~ /\[([A-Z|0-9]*)\] /;
        $tpe = $1;
        # Only marking the internal flag for IP->TRP 'UP', not the connection
        for $ent (@{$ent_list_by_ip{$ip}}) {
          $comm_list_by_ent{$ent}{$tpe} = UP;
        }
      }
      elsif ($line =~ /BTRPDISC/) {
        $line =~ /BTRPDISC\): (.+) has/;
        $ip = $1;
        for $ent (@{$ent_list_by_ip{$ip}}) {
          set_connection_down ($ent, $log_time, "IP");
        }
      }
      elsif ($line =~ /B2IPPABT/) {
        $line =~ /\((.+)\) EX\(B2IPPABT\):/;
        $ip = $1;
        for $ent (@{$ent_list_by_ip{$ip}}) {
          set_connection_down ($ent, $log_time, "IP");
        }
      }
      elsif ($line =~ /EXFLNDDW\): ([A-Z|0-9]*) \(/) {
        #We need to make sure it lost connection to all machines, not
        #just one (except for type B stuff, then only PROD01 needs to be down)
        $comm_engine = $1;
        if ($comm_engine =~ /USWPROD(CE[0-9]*)/ ) {
          $comm_engine = $1;
        }

        DBUG_PRINT("parse_rtlog", "%s DOWN at %s", $comm_engine, $log_time);

        # If $comm_engine is one of the TPEs, need to mark it 'down'
        if ($comm_engine =~ /USWPROD01|USWPROD02|USWPROD03|USWPROD04/) {
          $tpename = $comm_engine;
          for $comm_engine (sort keys %iploc) {
            for $ip (@{$iploc{$comm_engine}}) {

              DBUG_PRINT("parse_rtlog", ("TPE down - marking %s down for %s",
                                          $ip, $tpename));
              $comm_list_by_ent{$ip}{$tpename} = DOWN;
  
              # If ip is now down for all 3 tpes, set connection down
              # For type B IPs, only USWPROD01 needs to be down
              if (DOWN eq $comm_list_by_ent{$ip}{USWPROD01} &&
                  DOWN eq $comm_list_by_ent{$ip}{USWPROD02} &&
                  DOWN eq $comm_list_by_ent{$ip}{USWPROD03} &&
                  DOWN eq $comm_list_by_ent{$ip}{USWPROD04}) {
                DBUG_PRINT("parse_rtlog", 
                           ("%s now down on all TPEs, marking down", $ip));
                set_connection_down ($ip, $log_time, "CE");
              }
	      elsif ($ip =~ /-B2/ && $tpename =~ /USWPROD01/) {
                DBUG_PRINT("parse_rtlog", 
                           ("TPE down type b - marking %s down for %s",
                            $ip, $tpename));
                set_connection_down ($ip, $log_time, "CE");
	      }
            }
          }
        }
        # Loop through array of IP for comm engine and set the connection down.
        else {

          DBUG_PRINT("parse_rtlog",
                   ("%s is down, marking all it's connections down",
                    $comm_engine));
          for $ip (@{$iploc{$comm_engine}}) {
            set_connection_down ($ip, $log_time, "CE");
          }
        }
      }
    }
  }

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}

##
##SUBTTL send_outliers
##                                                        
## Parse the runtime log and determine outages
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub send_outliers {

  DBUG_ENTER("send_outliers");

  open MAIL, "> $outlierfile" or die "Can't open $outlierfile\n";

  for $outage (sort @outages) {

    ($time_down, $time_up, $ip) = split /\|/, $outage;

    # Covert the time down to the number of seconds since the new day
    $time_down =~ /(\d+):(\d+):(\d+)/;
    $dtime_down = $1 * 3600 + $2 * 60 + $3;
  
    # convert the time up to the number of seconds since the new day
    $time_up =~ /(\d+):(\d+):(\d+)/;
    $dtime_up = $1 * 3600 + $2 * 60 + $3;
  
    # Calculate the number of seconds down.
    $seconds_down = $dtime_up - $dtime_down;
    
    # Calculate the number of minutes the connection was down.
    $minutes_down = $seconds_down / 60;
    
    # If we are into 10 seconds into the next minute, round it up
    if (($seconds_down % 60) > 9) {
      $minutes_down++;
    }

    if ($minutes_down > 30) {
      DBUG_PRINT("send_outliers", "%s added to outlier list", $ip);
      DBUG_PRINT("send_outliers", "     minutes down: %d", $minutes_down);
      DBUG_PRINT("send_outliers", "%s: %s - %s = %d mins", 
                               $ip, $time_down, $time_up, $minutes_down);
      printf MAIL "%s: %s - %s = %d mins\n", 
                               $ip, $time_down, $time_up, $minutes_down;
    }
  }

  close MAIL;

  $SEND_MAIL = sprintf "/bin/mailx -s \"Downtime Outliers for %s\" %s < %s",
                       $date, $dist_list, $outlierfile;
  DBUG_PRINT("send_outliers", "%s", $SEND_MAIL);
  system $SEND_MAIL;

  $RM_MAIL = sprintf "/bin/rm %s", $outlierfile;
  DBUG_PRINT("send_outliers", "%s", $RM_MAIL);
  system $RM_MAIL;

  #This function doesn't actually return - just prints something
  DBUG_VOID_RETURN();
}



##
##SUBTTL calc_time_diff
##                                                        
## Takes two time format parameters and calculates the difference in 
## seconds between the two
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub calc_time_diff {

  # Split out parameters
  ($time1, $time2) = @_;

  # Calc number of seconds for time1
  ($h1, $m1, $s1) = split /:/, $time1;
#  $num_secs1 = $h1 * 3600 + $m1 * 60 + $s1; 
  $num_secs1 = ((($h1 * 60) + $m1) * 60) + $s1; 

  # Calc number of seconds for time2
  ($h2, $m2, $s2) = split /:/, $time2;
#  $num_secs2 = $h2 * 3600 + $m2 * 60 + $s2; 
  $num_secs2 = ((($h2 * 60) + $m2) * 60) + $s2; 
  
  if ($num_secs1 > $num_secs2) {
    $difference = $num_secs1 - $num_secs2;
  }
  else {
    $difference = $num_secs2 - $num_secs1;
  }

  return $difference;
}
