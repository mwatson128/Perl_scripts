#!/usr/local/bin/perl
# (]$[) packet_tally.pl:1.17 | CDATE=12/07/12 21:34:43
############################################################
##  Go grab all the netstat files from the TPE and the    ##
##  comm engines.  Mail a summary out and create a .csv   ##
##  file.                                                 ##
############################################################

##############################
##  Environment Definition  ##
##############################
$zone = `uname -n`;
chomp $zone;

# List of all the machines in the order that they will be displayed.
@machine_list = qw ( uswprod01 uswprod02 uswprod03 uswprod04 uswprodce01  uswprodce02 uswprodce03 uswprodce04 uswprodce05 uswprodce06 uswprodce07 uswprodce08 uswprodce09 uswprodce10 uswprodce11 uswprodce13 uswprodce14 uswprodce15
                   );

@short_machine_list = qw ( prd1 prd2 prd3 prd4 ce01 ce02 ce03 ce04 ce05 ce06 ce07
			   ce08 ce09 ce10 ce11 ce13 ce14 ce15
                         );

# Recipient list
$recipients = 'PEDPG@pegs.com';

# Root directory needed for processing
$root_dir = "/$zone/loghist/netstat";

# Check for date on command line
if ($ARGV[0] =~ /(\d+\/\d+\/\d+)/) {
  $date = $1;
}

# Otherwise grab yesterday's date
else {
  $date = `/$zone/usw/offln/bin/getydate -s`;
}

# Break apart the date and create relavent variables
($month, $day, $year) = split /\//, $date;
$monthdir = sprintf "%02d%02d", $month, $year;
$filedate = sprintf "%02d%02d%02d", $month, $day, $year;

# Make the monthdir
`/bin/mkdir $root_dir/$monthdir 2> /dev/null`; 

# Initialize minimum packets/sec hash
for $machine (@machine_list) {
  for ($i=0;$i < 24;$i++) {
    $hour = sprintf "%02d", $i;
    $min{$machine}{$hour} = 100000;
  }
}

##########################################
##  Get netstat files from all systems  ##
##########################################

for $machine (@machine_list) {

  # Different directories between CE and TPE
  if ($machine =~ "prodce") {
    $RCP_CMD = sprintf "/bin/scp usw\@%s:/pegs/%s/perf/kv/%s/netstat.%s %s/%s/netstat.%s.%s 2>/dev/null", $machine, $machine, $monthdir, $filedate, $root_dir, $monthdir, $machine, $filedate; 
  }
  else {
    $RCP_CMD = sprintf "/bin/scp usw\@%s:/%s/perf/kv/%s/netstat.%s %s/%s/netstat.%s.%s 2>/dev/null", $machine, $machine, $monthdir, $filedate, $root_dir, $monthdir, $machine, $filedate; 
  }
  system $RCP_CMD;
}

################################
##  Read and tally each file  ##
################################
for $machine (@machine_list) {
  
  # Build filename
  $netstat_file = sprintf "%s/%s/netstat.%s.%s", 
       $root_dir, $monthdir, $machine, $filedate;

  # Open netstat file
  open NETSTAT, $netstat_file;

  # Read and tally netstat file
  while ($line = <NETSTAT>) {
   
    # Ignore the hourly headers
    if ($line !~ /log cycle/) {

      # Snag the hour and pkts/sec from the line
      $line =~ /^\d+\/\d+\/\d+ (\d+):\d+:\d+ .* (\d+)\.\d+ pkt/;
      $hour = $1;
      $packets = $2;

      # Update the sum and num counters
      $sum{$machine}{$hour} += $packets;
      $num{$machine}{$hour}++;

      if ($packets < $min{$machine}{$hour}) {
        $min{$machine}{$hour} = $packets;
      }
    
      if ($packets > $max{$machine}{$hour}) {
        $max{$machine}{$hour} = $packets;
      }
    }
  }

  # Close netstat file
  close NETSTAT;
}

############################
##  Create E-mail report  ##
############################

# Open E-mail pipe for delivery
open MAIL, "| /bin/mailx -s \"Network Utilization for $date\" $recipients";

# Build the header and border
$header = sprintf "%s", $date;
$border = "--------";
for $machine (@short_machine_list) {
  $header .= sprintf "|%5s", $machine;
  $border .= "+-----";
}

# Write the header and border
print MAIL $header . "\n";
print MAIL $border . "\n";

# Loop through each hour
for ($hour = 0;$hour < 24;$hour++) {

  # Pad with a zero if needed
  $hour = sprintf "%02d", $hour;
  
  # Build each line of output
  $line = sprintf "%02d:00:00", $hour;
  for $machine (@machine_list) {

    # Calculate the average 
    if ($num{$machine}{$hour} > 0) {
      $average = $sum{$machine}{$hour} / $num{$machine}{$hour};
    }
    else {
      $average = 0;
    }

    $line .= sprintf "|%5d", $average;
    $day_sum{$machine} += $sum{$machine}{$hour};
    $day_num{$machine} += $num{$machine}{$hour};
  }

  # Write the line
  print MAIL $line . "\n";
}

$line = sprintf "%s", $date;
for $machine (@machine_list) {
  if ($day_num{$machine} > 0) {
    $average = $day_sum{$machine} / $day_num{$machine};
  }   
  else {
    $average = 0;
  }
  $line .= sprintf "|%5d", $average;
}

print MAIL $border . "\n";
print MAIL $line . "\n";

# Close and deliver mail pipe
close MAIL;

###########################################
##  Create .csv file for easy importing  ##
###########################################

# Build filename for .csv file
$csv_file = sprintf "%s/%s/netstat_summary_%s.csv", 
     $root_dir, $monthdir, $filedate;

# Open the .csv file
open CSV, "> $csv_file" or die "Can't open $csv_file.\n";

$header1 = sprintf "%s", $date;
for $machine (@machine_list) {
  $header1 .= sprintf ",%s,,", $machine;
  $header2 .= ",MIN,AVG,MAX";
}

print CSV $header1 . "\n";
print CSV $header2 . "\n";

for ($hour = 0;$hour < 24;$hour++) {

  $hour = sprintf "%02d", $hour;
  $line = sprintf "%02d:00:00", $hour;
  for $machine (@machine_list) {

    # Calculate the average
    if ($num{$machine}{$hour} > 0) {
      $average = $sum{$machine}{$hour} / $num{$machine}{$hour};
    }
    else {
      $average = 0;
    }

    # Update the line
    $line .= sprintf ",%d,%d,%d", 
         $min{$machine}{$hour}, $average, $max{$machine}{$hour};
  }
  
  # print the line
  print CSV $line . "\n";
}

# Close the .csv file
close CSV;
