#!/bin/perl 
###########################################################################
#
# This will eventually be an AMF parser for breaking an AMF message down
# into it segments and fields.
#
###########################################################################

use Getopt::Std;

# Usage statement.
$us = "Usage: amf_parse.pl [-o format] amf_message_file 
   -o format = reports output ('ascii' produces ASCII output, 
      'latex' yeilds LaTeX output, 'html' yeilds HTML, etc.)  
      [default is ASCII]\n";

# Defines and information hash's...

# Required hash
%reqir = (
  "0" => "Not Required",
  "1" => "Required",
);

# Validate hash
%valid = (
  "0" => "Don't Validate",
  "1" => "Validate",
);

# C_TYPE defines:
%c_types = (
  "eqfAMF_VARCHAR" => "Character",
  "eqfAMF_VARSTAR" => "Character",
  "eqfAMF_VARSHORT" => "Integer",
  "eqfAMF_VARLONG" => "Integer",
  "eqfAMF_VARUNSIGNED" => "Unsigned Integer",
  "eqfAMF_VARDOUBLE" => "large Integer",
  "eqfAMF_VARUTF8" => "UTF8 Character",
);

# DATATYPE defines:
%data_types = (
  "ALPHABETIC" => "ALPHABETIC",
  "NUMERIC" => "NUMERIC",
  "ALPHANUMERIC" => "ALPHANUMERIC",
  "HEX" => "HEX",
  "ANY" => "ANY",
  "UTF8" => "UTF8",
  "RATE" => "RATE",
  "eqnAMF_EDITALPHA" => "Alphabetic",
  "eqnAMF_EDITNUMERIC" => "Numeric",
  "eqnAMF_EDITALPHANUM" => "Alphanumeric",
  "eqnAMF_EDITHEX" => "Hex",
  "eqnAMF_EDITANY" => "Any",
  "eqnAMF_EDITUTF8" => "UTF8",
  "eqnAMF_EDITRATE" => "Rate",
  "AMF_DTMASK" => "NA",
  "AMF_EDTRIMLEADINGSPACES" => "Leading spaces",
  "AMF_EDTRIMTRAILINGSPACES" => "Trailing spaces",
  "AMF_NOTPRESIFNODATA" => "Not present if no data",
  "eqfAMF_EDITMASK" => "NA",
  "eqfAMF_EDITTRIMLEADSP" => "Leading spaces",
  "eqfAMF_EDITTRIMTRAILSP" => "Trailing spaces",
  "eqfAMF_EDITNOTPRESIFNODATA" => "Not present if no data",
);

$errors = getopts('hi:');

# help option. Print usage and exit.
if ($opt_h) {
  print $us;
  exit;
}

# Define the input
if ( $opt_o ) {
  $OUTFILE = "> $opt_o"; 
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
#open OUTFILE or die "Can't open file $OUTFILE";

$line_ind = 0;
$msg_array = "";
$start_xdf = 0;

while (<INFILE>) {
  
  next if /^#|^$/;
  next if /^\/\*|^\*\*|^\*\//;
  next if /uint32/;
  chomp;


  if (/struct xdfdesc_s/) {
    if ($start_xdf != 0) {
      $start_xdf++;
    }
    $lg_var[$start_xdf] = $_;
  }
  else {
    if (/\{/) {
      $start_xdf++;
    }
    $lg_var[$start_xdf] .= $_;
  }
}
close INFILE;

print "Segment, AMF tag, C name, C Type, Dim 1, Dim 2, Data type, Max, Min, Required, Validate\n";

foreach $ln (@lg_var) {

  @tmp1 = split /\{/, $ln;
  @tmp2 = split /\}/, $tmp1[1];
  @mems = split /\,/, $tmp2[0];

  if (!$tmp1[1]) {
    # This is the struct header.
    ($st, $xdf, $name) = split / +/, $tmp1[0];
    ($temp, @else) = split /\[/, $name;
    ($seg, @else) = split /_/, $temp;
  }
  elsif ($ln =~ /\(char \*\)0/) {
    # End of this struct.
    print "\n";
    
  }
  else {
    # This is the real data.
    $mems[0] =~ s/"//g;
    $mems[4] =~ s/"//g;

    $max = eval $mems[6];
    $min = eval $mems[7];

    # get rid of spaces
    foreach $foo (@mems) {
      $foo =~ s/ +//g;
    }
      
    $type = $c_types{$mems[1]};  
    $data_t = $data_types{$mems[5]};
    $req = $reqir{$mems[8]};  
    $val = $valid{$mems[9]};  
    $uc_seg = uc $seg;

    print "$uc_seg, $mems[4], $mems[0], $type, $mems[2], $mems[3],";
    print " $data_t, $max, $min, $req, $val\n";
  }
}

#print "$ln, \n";

#@segments = split /\|\|+/, $msg_array;
#foreach $segment (@segments) {

#  next if $segment eq "00";
  #print "SEGMENT: $segment\n";

#  if (1 != (@hdr = split /(RTENV)/, $segment)) {
#    shift @hdr;
#    $segment = $hdr[0] . $hdr[1];
#    print "\n";
#  }

  
