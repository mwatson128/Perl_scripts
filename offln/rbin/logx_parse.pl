#!/bin/perl 
###########################################################################
#
#
#
###########################################################################
chdir "/uswsup01/usw/offln/daily";

if (defined $ARGV[0]) {
  # get co file name from argv
  $co_filename = "rpt" . $ARGV[0] . ".co";
  $backfilename = "rpt" . $ARGV[0] . ".co-";

  qx(cp $co_filename $backfilename);
  if (-f $co_filename) {
    $IFP = "< $co_filename";
    $OFP = "> $co_filename";
  }
  else {
    print "$co_filename, not a regular file.\n";
    exit;
  }
}
else {
  print "date_parse.pl <date> \n";
  exit;
}

# Make up a no less than time stamp 
$ARGV[0] =~ /(\d\d)(\d\d)(\d\d)/;
$tmdate = "$1/$2/$3 00:00:00";

$predate = `/uswsup01/usw/offln/bin/tstamp -t \"${tmdate}\" -o d`; 
chomp $predate;
$target_tmdate = $predate - 7200;

open IFP or die "Can't open file $co_filename";
@co_file_input = <IFP>;
close IFP;

foreach $ln (@co_file_input) {
  @fields_ifp = split /\|/, $ln;
  $keepit = 1;

#
#1  2  3 4 5              6  7     8       9 10 11     12     13 14 15 16 17
#A|GT|WB| | |1606F409092005|SS|50231|05JUN12|6 |1 |046223|A02EAR|  |0 |UC|  |
#        18         19 20 21         22         23        24 25 26        27
#1329631378|1329631378|0 |0 |1329631378|2147483647|115989682|0 |0 |115993855

  if ($fields_ifp[18] && ($fields_ifp[18] < $target_tmdate)) {
    $keepit = 0;
  }
  if ($fields_ifp[0] eq "") {
    $keepit = 0;
  }
  if ($fields_ifp[6] eq "") {
    $keepit = 0;
  }

  if ($keepit) {
    push @co_file_out, $ln;
  } 
}

open OFP;
foreach $ln (@co_file_out) {
  printf OFP $ln;
}
close OFP;


