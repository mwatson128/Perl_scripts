#!/bin/perl 
###########################################################################
#
# This will eventually be an AMF parser for breaking an AMF message down
# into it segments and fields.
#
###########################################################################

use Getopt::Std;

# Usage statement.
$us = "Usage: ddown_count.pl <RTLOG FILE> 
        Read in RTLOG FILE, compile counts of dest down and report\n";

$errors = getopts('ho:');

# help option. Print usage and exit.
if ($opt_h) {
  print $us;
  exit;
}

if (defined $ARGV[0]) {
  if (-f $ARGV[0]) {
    $INFILE = "< $ARGV[0]";
  }
  else {
    print "$ARGV[0], not a regular file.\n";
    print $us;
    exit;
  }
}
else {
  print $us;
  exit;
}

open INFILE or die "Can't open file $INFILE";

$line_ind = 0;
$msg_array = "";

while (<INFILE>) {
  
  next if /^#|^$/;
  chomp;

  if (/Destination down/) {
  
    if (/<= (\d\d)\/(\d\d)\/(\d\d) (\d\d):(\d\d):(\d\d)/) {
      $t_hour = $4;
      $t_min = $5;
      $t_sec = $6;
    }
    if (/cannot send message to (..)/) {
      $hrs_code = $1;
    }
    if (/\((A-Z+)-A2\):/) {
      $gds_code = $1;
    }

    #next if ($hrs_code =~ /DI|HJ|SE|RA|BU|KG|MQ|TL|WG|/);
    $key_p = $t_hour . $t_min . $t_sec . $hrs_code;
    $sub_p = "$t_hour:$t_min:$t_sec $gds_code and $hrs_code is down\n";
    $time_hrs{$key_p} = $sub_p;

  }

}

close INFILE;

#print %time_hrs hash

foreach $key (sort %time_hrs) {
  print $time_hrs{$key};
}

  
  
