#!/usr/local/bin/perl
# (]$[) dbcount.pl:1.3 | CDATE=07/14/09 11:05:06
######################################################################
# This script goes through the runtime log and pulls out the DEST
# BUSY lines and dumps an hourly breakdown for each HRS by GDS, for 
# each GDS by HRS, and then a total by hour broken down by GDS.
######################################################################

#######################################
#  General config and variable setup  #
#######################################
$numcols = 8;  # Max number of columns to print before wrapping
@gdslist = qw "AA UA 1P 1A WB MS HD";  # List of all GDS's
$gdslist = join " ", @gdslist;  # Same list, but in a single var
$hrsmax = 0;  # A count of all HRSs that has timeouts
$hrslist=""; # Will become a string list of the HRSs
$zone = `uname -n`;
chomp $zone;
$log_dir = "/$zone/loghist/uswprod01";
$db_dir = "/$zone/usw/reports/daily/dstblogs/";
$master_config="$log_dir/master/master.cfg";

##################################################################
#  Generate a list of the HRSs based off the HRS_EQUIVALENCE in  #
#  master.cfg                                                    #
##################################################################
open MASTER, $master_config or die "Can't open $master_config.\n";
while ($line = <MASTER>) {
  if ($line !~ /^$|^#/) {
    $hold = "";
    while ($line =~ /\\$/) {
      chomp $line;
      chop $line;
      $hold = $hold . $line;
      $line=<MASTER>;
    }
    chomp $line;
    $hold = $hold . $line;
    if ($line =~ /{/) {
      chomp $line;
      chop $line;
      chop $line;
      $config_type = $line;
      %hold = ();
    } elsif ($line =~ / = /) {
      ($key, $value) = split / = /, $hold;
      $hold{$key} = $value;
    } else {
      if ($config_type eq "HRS_EQUIVALENCE") {
        $hrs_equi{$hold{PRIMARY_ID}} = $hold{HRS};
      }
    }
  }
}
close MASTER;

for $hrs (sort keys %hrs_equi) {
  $hrslist[$hrsmax++] = $hrs;
  $hrslist = $hrslist . " " . $hrs;
}

###################################################
#  Set the date and locate the rtlog in loghist  #
###################################################
if ($#ARGV < 0) {
  $date=`/$zone/usw/offln/bin/getydate -s`;
} else {
  if ($ARGV[0] =~ /^\d\d\/\d\d\/\d\d$/) {
    $date = $ARGV[0];
  } else {
    die "Invalid date formate: mm/dd/yy\n";
  }
}
($month, $day, $year) = split /\//, $date;
$day = $day + 0;
$rtlogfile = "$log_dir/rtlogs/" . $month . $year . "/rtlog" . $day;
$dblogfile = $db_dir . $month . $year . "/dblog" . $day;

# Create the month dir, and if it errors, just ignore it.
`/bin/mkdir $db_dir/$month$year 2>&1 > /dev/null`;

# Close STDOUT and open it as the dblog file.  Comment out these two
# lines if you want to run this to the display.
close STDOUT;
open STDOUT, "> $dblogfile" or die "Can't open dblog file $dblogfile\n";

#######################################################################
#  Open the rtlog file and start parsing the data.  Build the hash
#  while the data is parsed.  This seems to save a lot of mem usage,
#  although overall execution time increases, it stil takes less
#  than 30 seconds to run a day.  Two hashes are created.
#######################################################################
open RTLOG, $rtlogfile or
  open RTLOG, "gunzip -c $rtlogfile |" or
  die "Can't open rtlog file $rtlogfile\n";
while ($block = <RTLOG>) {

  # Grab only context timeout lines
  if ($block =~ /DSTB/) {                     

    # This is here because once in a while multiple rtlog entries will
    # somehow make it to the same logical line, so split on the "["
    # that encapsulates a machine name.  All CTTM lines come from a 
    # comm engine so all that will be there.
    @block = split /\[/, $block;             

    # Treat each piece of the line as a separate line
    for $line (@block) {

      # Double check to see if its a DSTB
      if ($line =~ /DSTB/) { 

        # Split the line on white space and produce the needed vars
        @line = split / +/, $line;
        ($junk, $hrs) = split /\:/, $line[11]; 
        ($junk, $gds) = split /\:/, $line[12]; 

        # In the even that the GDS ID in the message is not the base
        for $gds_base (@gdslist) {
          if ($gds =~ /$gds_base/) {
            $gds = $gds_base;
          }
        }

        @ip = split //, $line[4];
        shift @ip;
        $hold = join "", @ip;
        ($ip, $junk) = split /-/, $hold;
        ($hour, $minute, $second) = split /\:/, $line[3];
        # This is here to remove all timeouts except for the one the
        # GDS reports.  if the gds var is in the gdslist and the ip
        # matches the gds or WS (gds=1P, IP=WS), then increment the
        # count.
        if ($ip =~ /^$hrs/) {
          $hrsdb{$hrs}{$gds}[$hour]++;
        } else {
          $gdsdb{$hrs}{$gds}[$hour]++;
        }
      }
    }
  }
}
close RTLOG;

######################################
# Print a header on the output file. #
######################################
printf "Type A message timeout report for %s\n", $date;
print "-" x 42 . "\n";

#########################################
#  Print out the HRS breakdown by hour  #
#########################################
for $hrs (@hrslist) {
  $hour = 0;
  %total = ();
  printf "%2s  |", $hrs;
  for $gds (@gdslist) {
    printf "  %5s", $gds;
  }
  print "  Total\n----+";
  for $gds (@gdslist) {
    print "-------";
  }
  print "--------\n";
  while ($hour < 24) {
    printf "%2s  |", $hour;
    $total = 0;
    for $gds (@gdslist) {
      printf"  %5d", $hrsdb{$hrs}{$gds}[$hour]; 
      $total = $total + $hrsdb{$hrs}{$gds}[$hour];
      $total{$gds} = $total{$gds} + $hrsdb{$hrs}{$gds}[$hour];
    } 
    printf "  %5s\n", $total;
    $hour++;
  }
  print "----+";
  for $gds (@gdslist) {
    print "-------";
  }
  print "--------\n";
  print "Total";
  $total = 0;
  for $gds (@gdslist) {
    printf "  %5d", $total{$gds};
    $total = $total + $total{$gds};
  }
  printf "  %5s\n\n", $total;
}

#################################
#  Print GDS breakdown by hour  #
#################################
%gdstotal=();
for $gds (@gdslist) {
  for ($i=0;$i < $hrsmax / $numcols;$i++) {
    %total = ();
    $hour = 0;
    $idxstart = $i * $numcols;
    if ($idxstart + $numcols > $hrsmax) {
      $idxstop = $hrsmax;
    } else {
      $idxstop = $idxstart + $numcols;
    }
    printf "%2s  |", $gds;
    for ($hrsidx = $idxstart;$hrsidx < $idxstop;$hrsidx++) {
      printf "  %5s", $hrslist[$hrsidx];
    }
    print "\n----+";
    for ($hrsidx = $idxstart;$hrsidx < $idxstop;$hrsidx++) {
      print "-------";
    }
    print "-\n";
    while ($hour < 24) {
      printf "%2s  |", $hour;
      for ($hrsidx = $idxstart;$hrsidx < $idxstop;$hrsidx++) {
        $hrs = $hrslist[$hrsidx];
        printf"  %5d", $gdsdb{$hrs}{$gds}[$hour]; 
        $total{$hrs} = $total{$hrs} + $gdsdb{$hrs}{$gds}[$hour];
        $gdstotal{$gds}[$hour] = $gdstotal{$gds}[$hour] + $gdsdb{$hrs}{$gds}[$hour];
      } 
      print "\n";
      $hour++;
    }
    print "----+";
    for ($hrsidx = $idxstart;$hrsidx < $idxstop;$hrsidx++) {
      print "-------";
    }
    print "-\n";
    print "Total";
    for ($hrsidx = $idxstart;$hrsidx < $idxstop;$hrsidx++) {
      $hrs = $hrslist[$hrsidx];
      printf "  %5d", $total{$hrs};
    }
    print "\n\n";
  }
}

###############################
#  Start GDS summary by hour  #
###############################
%total = ();
print "    |";
for $gds (@gdslist) {
  printf "  %5s", $gds;
}
print "  Total\n";
print "----+";
for $gds (@gdslist) {
  print "-------";
}
print "--------\n";
for ($hour = 0;$hour < 24;$hour++) {
  printf "%2s  |", $hour;
  $total = 0;
  for $gds (@gdslist) {
    printf "  %5s", $gdstotal{$gds}[$hour]; 
    $total{$gds} = $total{$gds} + $gdstotal{$gds}[$hour];
    $total = $total + $gdstotal{$gds}[$hour]; 
  }  
  printf "  %5s\n", $total;
}
print "----+";
for $gds (@gdslist) {
  print "-------";
}
print "--------\n";
print "Total";
$total = 0;
for $gds (@gdslist) {
  printf "  %5d", $total{$gds};
  $total = $total + $total{$gds};
}
printf "  %5d\n", $total;
