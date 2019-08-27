#!/usr/local/bin/perl
###########################################################################
##  (]$[) dt_update.pl:1.1 | CDATE=04/21/03 04:18:52                                        ##
###########################################################################
##  This script is designed to give operations a tool to update the      ##
##  downtime database with the remedy numbers associated with outages.   ##
##  Usage:  dt_update.pl <Remedy Number>_<Outage Code>                   ##
###########################################################################

##########################
##  Parse the filename  ##
##########################
$filename = $ARGV[0];
 
# Check filename format
if ($filename =~ /^\d+_..$/) {

  # Split the filename and assign the remedy number and outage code
  ($remedy_number, $outage_code) = split /_/, $filename;
}
else {

  # Invalid file format.  Print error message and exit.
  print "Invalid file format\n";
  print "Format:  <Remedy Number>_<Outage Code>\n";
  print "Example:  123456_TQ\n";
  print "Rename file and rerun.\n";
  exit 1;
}

#######################################
##  Open file and load outage times  ##
#######################################

open FILE, $filename or die "Can't open $filename.\n";

# Read and parse outage times from file
while ($line = <FILE>) {

  # Remove that nasty newline character.
  chomp $line;
  
  # Check date and time format
  if ($line =~ /^(\d+\/\d+\/\d+ \d+:\d+:\d+)/) {
    $outage_time = $1;
    push @outages, $outage_time;
  }

  # Invalid outage time format.  Print error message and exit.
  else {
    print "Invalid outage time format within file: $line\n";
    print "Format: mm/dd/yy hh:mm:ss\n";
    print "Example: 07/08/03 14:12:21\n";
    print "Reformat outages time and rerun.\n";
  }
}

close FILE;

######################
##  Update outages  ##
######################

# Setup update SQL script
$update_sql = sprintf "database usw_perf;\n";
$update_sql .= sprintf "update downtime\n";
$update_sql .= sprintf "set ticket = \"%s\", o_code = \"%s\"\n", 
     $remedy_number, $outage_code;
#$update_sql .= sprintf "set o_code = %s\n", $outage_code;

# Load in first time
$time = pop @outages;
$dtime = `/usw/offln/bin/tstamp -t \"$time\" -o d`;
chomp $dtime;
$update_sql .= sprintf "where time_d = %s\n", $dtime;

# Cycle through the other outages and add them to the query
for $time (@outages) {
  
  # Load up the outage
  $dtime = `/usw/offln/bin/tstamp -t \"$time\" -o d`;
  chomp $dtime;
  $update_sql .= sprintf "or time_d = %s\n", $dtime;
  
}

# Open the ISQL pipe
open ISQL, "| isql" or die "Can't open ISQL pipe.\n";

# Run the update
print ISQL $update_sql;

# Close the ISQL pipe
close ISQL;
