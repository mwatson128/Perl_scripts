#!/bin/perl 
###########################################################################
#
# This will eventually be an AMF parser for breaking an AMF message down
# into it segments and fields.
#
#
#
#
#
#
#
#
###########################################################################

use Getopt::Std;

# Usage statement.
$us = "Usage: amf_parse.pl [-o format] amf_message_file 
   -o format = reports output ('ascii' produces ASCII output, 
      'latex' yeilds LaTeX output, 'html' yeilds HTML, etc.)  
      [default is ASCII]\n";

$errors = getopts('ho:');

# help option. Print usage and exit.
if ($opt_h) {
  print $us;
  exit;
}

# Define the output format.
if ( !$opt_o ) {
  $outformat = "ascii";
}
elsif ( $opt_o eq "html" ) {
  $outformat = "html";
}
elsif ( $opt_o eq "csv" ) {
  $outformat = "csv";
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
  next if /plcf/ || /gwif/ || /ret/;
  chomp;
  s/\\//g;
  $msg_array .= $_;
}
close INFILE;

#print $msg_array, "\n\n";

@segments = split /\|\|+/, $msg_array;

$num_segs = @segments;

foreach $segment (@segments) {

  next if $segment eq "00";
  #print "SEGMENT: $segment\n";

  if (1 != (@hdr = split /(RTENV)/, $segment)) {
    shift @hdr;
    $segment = $hdr[0] . $hdr[1];
    print "\n";
  }

  if (1 != (@hdr = split /(HDR)/, $segment)) {
    shift @hdr;
    $segment = $hdr[0] . $hdr[1];
    print "\n" 
  }

  @fields = split /\|/, $segment;
  $num_fields = @fields;
  if (2 <= $num_fields) {
    print "     $fields[0]\n";
    shift @fields;
    foreach $field (@fields) {
      @b_field = split //, $field;
      $nm = $b_field[0] . $b_field[1] . $b_field[2];
      shift @b_field;
      shift @b_field;
      shift @b_field;
      $rest = join / /, @b_field;
      print "        $nm = $rest\n";

      #print "        $field\n";
    }
  }
}
  
  
