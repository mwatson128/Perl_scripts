#!/bin/perl
###########################################################################
#
# This prog will read in a line of text + plus non-printables, either UTF8
# or wizcom logs and fill a space where the unprintable was.  So the file
# can be grep'ed and searched correctly.
#
###########################################################################

use Getopt::Std;

# Usage statement.
$us = "Usage: de_bin message_file\n";

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
    print $ARGV[0];
    print $us;
    exit;
  }
}
else {
  print $us;
  exit;
}

open INFILE or die "Can't open file $INFILE";

$msg_array = "";

while ($msg_array = <INFILE>) {
  $msg_array =~ s/\34/'/g;
  $msg_array =~ s/\35/+/g;
  $msg_array =~ s/\37/:/g;
  $msg_array =~ tr/a-zA-Z0-9'+:/ /c;
  print "$msg_array\n";
  $msg_array = "";
}
close INFILE;
  
