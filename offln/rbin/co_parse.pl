#!/bin/perl 
###########################################################################
#
#
#
###########################################################################

if (defined $ARGV[0]) {
  if (-f $ARGV[0]) {
    $INFILE = "< $ARGV[0]";
  }
  else {
    print "$ARGV[0], not a regular file.\n";
    exit;
  }
}
else {
  exit;
}

open INFILE or die "Can't open file $INFILE";

while (<INFILE>) {
  chomp;
  @fields_ifp = split /\|/;
#
#1  2  3 4 5              6  7     8       9 10 11     12     13 14 15 16 17
#A|GT|WB| | |1606F409092005|SS|50231|05JUN12|6 |1 |046223|A02EAR|  |0 |UC|  |
#        18         19 20 21         22         23        24 25 26        27
#1329631378|1329631378|0 |0 |1329631378|2147483647|115989682|0 |0 |115993855
  @timedate = `tstamp -h $fields_ifp[5]`; 
  chomp $timedate[1];
  $co_key = $fields_ifp[22] . "-" . $fields_ifp[5];
  unshift @fields_ifp, $timedate[1];
  $printdata = join '|', @fields_ifp;
  $co_hash{$co_key} = $printdata;
}
close INFILE;

foreach $co_element (sort keys %co_hash) {
  print "$co_element - ";
  print "$co_hash{$co_element}\n";
}
  
