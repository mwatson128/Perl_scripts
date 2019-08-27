#!/bin/perl 
###########################################################################
#
# This will eventually be an AMF parser for breaking an AMF message down
# into it segments and fields.
#
###########################################################################

use Getopt::Std;

# Usage statement.
$us = "Usage: gen_pidfile.pl pid_file \n";

$errors = getopts('h');

# help option. Print usage and exit.
if ($opt_h) {
  print $us;
  exit;
}

for($i = 0; $i <= 7000; $i++) {
  $pid = 10000 + $i;
  print("$pid|Y|AA$pid|UA$pid|1A$pid|WS$pid|WB$pid|\n");
}

  
