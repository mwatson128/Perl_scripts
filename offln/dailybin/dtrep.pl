#!/usr/local/bin/perl
# (]$[) dtrep.pl:1.4 | CDATE=05/10/03 12:41:46
###########################################################################
## Utility to run reports against the downtime table in the usw_perf 
## database.  The default for this utility will be to run a report against
## the previous day showing all downtimes.  Options will allow to run 
## the report for any interval and to limit scope based on IP.
###########################################################################

###########################################################################
## Forward declare subroutines
###########################################################################
sub usage;
sub set_defaults;
sub parse_command_line;
sub build_sql;
sub run_sql;
sub output_results;

###########################################################################
## MAIN 
###########################################################################
set_defaults();
parse_command_line();
build_sql();
run_sql();
output_results();

###########################################################################
## Something went wrong so drop usage and exit
###########################################################################
sub usage {

  # If an arguement was given to usage print it as error output
  if ($_[0]) {
    $error_message = $_[0];
    chomp $error_message;
    print STDERR $error_message . "\n";
  }

  # Print usage statement
  print STDERR "usage dtrep.pl [-s date_time] [-e date/time] [-i iplist]\n";
  print STDERR "   -s date_time - This is the start date and time for the report.\n                  Format date and time as MM/DD/YY[_HH:MM:SS].\n";
  print STDERR "   -e date_time - This is the end date and time for the report.\n                  Format Date using the same format as -s.\n";
  print STDERR "   -i iplist    - A space delimited list of IPs to report on.\n";
  print STDERR "   -z timezone  - Override timezone of GMT for time information.\n";
  exit;
}

###########################################################################
## Set default values to use which can be overridden by command line 
## options.
###########################################################################
sub set_defaults {
  $s_date = `/usw/offln/bin/getydate -s`;
  $s_time = `/usw/offln/bin/tstamp -t $s_date -od`;
  chomp $s_time;
  $e_time = $s_time + 86400;
  $db_name = "usw_perf";
  $dt_table = "downtime";
  $ENV{TZ}="GMT";
}

###########################################################################
## Parse command line options and change variables as needed.
###########################################################################
sub parse_command_line {

  # Default optind value which is effectivly "null".
  $optind = "NO IND";
  
  # Loop through ARGV array to build opts hash
  for $arg (@ARGV) {
    
    # If there is a "-" in the front of the arg, then we have found a new 
    # options
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
        usage("Ivalid option\n");
      }
    }
  }

  # Set variables on options found on the command line
  for $optind (sort keys %opts) {
    
    # Use start time specified, and modify end date based on start time
    # granularity
    if ($optind eq "s") {
      if ($opts{$optind}[0] =~ /(\d\d\/\d\d\/\d\d)_(\d\d:\d\d:\d\d)/) {
        $date = $1;
        $time = $2;
        ($h, $m, $s) =~ /(\d\d):(\d\d):(\d\d)/;
        $s_time = `/usw/offln/bin/tstamp -t $date -od` 
             + (3600 * $h) + (60 * $m) + $s;
        if ($opts{"e"}[0] eq "") {
          $e_time = $s_time + 1;
        }
      } 
      elsif ($opts{$optind}[0] =~ /(\d\d\/\d\d\/\d\d)_(\d\d:\d\d)/) {
        $date = $1;
        $time = $2;
        ($h, $m) =~ /(\d\d):(\d\d)/;
        $s_time = `/usw/offln/bin/tstamp -t $date -od` + (3600 * $h) + (60 * $m);
        if ($opts{"e"}[0] eq "") {
          $e_time = $s_time + 60;
        }
      }
      elsif ($opts{$optind}[0] =~ /(\d\d\/\d\d\/\d\d)_(\d\d)/) {
        $date = $1;
        $h = $2;
        $s_time = `/usw/offln/bin/tstamp -t $date -od` + (3600 * $h);
        if ($opts{$optind}[0] eq "") {
          $e_time = $s_time + 3600;
        }
      }
      elsif ($opts{$optind}[0] =~ /(\d\d\/\d\d\/\d\d)/) {
        $date = $1;
        $s_time = `/usw/offln/bin/tstamp -t $date -od`;
        if ($opts{"e"}[0] eq "") {
          $e_time = $s_time + 86400;
        }
      } 
      else {
        usage ("Date/Time format invalid.");
      }
    }

    # Use end time specified, and modify end date based on start time 
    # granularity if -e was not specified on the command line.
    elsif ($optind eq "e") {
      if ($opts{$optind}[0] =~ /(\d\d\/\d\d\/\d\d)_(\d\d:\d\d:\d\d)/) {
        $date = $1;
        $time = $2;
        ($h, $m, $s) =~ /(\d\d):(\d\d):(\d\d)/;
        $e_time = `/usw/offln/bin/tstamp -t $date -od` 
             + (3600 * $h) + (60 * $m) + $s;
      } 
      elsif ($opts{$optind}[0] =~ /(\d\d\/\d\d\/\d\d)_(\d\d:\d\d)/) {
        $date = $1;
        $time = $2;
        ($h, $m) =~ /(\d\d):(\d\d)/;
        $e_time = `/usw/offln/bin/tstamp -t $date -od` + (3600 * $h) + (60 * $m);
      }
      elsif ($opts{$optind}[0] =~ /(\d\d\/\d\d\/\d\d)_(\d\d)/) {
        $date = $1;
        $h = $2;
        $e_time = `/usw/offln/bin/tstamp -t $date -od` + (3600 * $h);
      }
      elsif ($opts{$optind}[0] =~ /(\d\d\/\d\d\/\d\d)/) {
        $date = $1;
        $e_time = `/usw/offln/bin/tstamp -t $date -od`;
      } 
      else {
        usage ("Date/Time format invalid.");
      }
    }

    # Override time display from GMT
    elsif ($optind eq "t") {
      $ENV{TZ} = $opts{$optind};
    }
 
    # Report only IPs specified on -i
    elsif ($optind eq "i") {
      @ip_list = @{$opts{$optind}};
    }
 
    # Error because of invalid option
    else {
      usage("Invalid option.");
    }
  }

  # Make sure that start date is earlier then end date
  if ($s_time > $e_time) {
    usage("Start time (-s) must be earlier than end time (-e).");
  }
}

sub build_sql {

  $ISQL = sprintf "select * from %s\n", $dt_table;
  $ISQL .= sprintf "where (time_d >= %s and time_d < %s)\n", $s_time, $e_time;
  
  # Load iplist into ISQL if array contains values
  if (@ip_list) {
    $ISQL .= sprintf "and conn in (";
    for $ip (@ip_list) {
      $ISQL .= sprintf "\'%s\',", $ip;
    }
    
    # Remove last comma
    chop $ISQL;
  
    # Finish end of ISQL 
    $ISQL .= sprintf ")";
  }
}

###########################################################################
## Execute ISQL statement that was built capturing the output into @results
###########################################################################
sub run_sql {
  
  # Run SQL and store findings in @results
  @results = `/informix/bin/isql $db_name <<EOSQL;
$ISQL
`;
EOSQL
;
}

sub output_results {

  # Print report header
  print "    Time Down           Time Up        entity   ticket  o_code\n";
  
  # Reformat time in time_d and time_u fields so that normal people can read
  # and understand it
  for $result (sort @results) {

    # Only process actual downtime
    if ($result =~ /\d+ +\d+/) {
  
      # Strip newline character
      chomp $result;

      # Grab data from result
      ($junk, $time_d, $time_u, $entity, $ticket, $o_code, $junk) = 
           split / +/, $result;

#      printf "time_d = %s\n", $time_d;
#      printf "time_u = %s\n", $time_u;
#      printf "entity = %s\n", $entity;
#      printf "remedy = %s\n", $ticket;
#      printf "o_code = %s\n", $o_code;

      # Calculate downtime and also minutes down.  
      $downtime = $time_u - $time_d;
      $minutes_down = $downtime / 60;

      # If we are 10 seconds into the next minute, then lets add another 
      # minute of downtime
      if (($downtime % 60) > 9) {
        $minutes_down++;
      }

      # Convert the down time and up time to human readable format using 
      # tstamp and remove the trailing end of line character if it is there
      $time_down = `/usw/offln/bin/tstamp -d $time_d`;
      chomp $time_down;
      $time_up = `/usw/offln/bin/tstamp -d $time_u`;
      chomp $time_up;

      # Print the outage
      printf "%17s  %17s  %-8s  %6s   %3s\n", 
           $time_down, $time_up, $entity, $ticket, $o_code;
    }
  } 
}
