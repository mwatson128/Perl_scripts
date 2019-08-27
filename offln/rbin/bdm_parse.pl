#!/bin/perl 
###########################################################################
#
#
#
###########################################################################
chdir "/uswsup01/usw/offln/daily/bdm";

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
$target_tmdate = $predate - 3600;

open IFP or die "Can't open file $co_filename";
@co_file_input = <IFP>;
close IFP;

foreach $ln (@co_file_input) {
  @fields_ifp = split /\|/, $ln;

  $keepit = 1;

#   BDM MESSAGE
#1  2  3 4 5              6      7      8  9 10 11 12 13 14 
#WY|AA|A| |u|1001F4D6AD43DE|6C4ED4|290001|AA|  |ET|UC|  |  |
#                 15 16 17 18 19 20 21 22 23         24 25 26 27 28 29 30
#02/29/2012 00:01:23|WY|2 |  |  |  |  |  |  |WITTE/DEAN|0 |0 |0 |0 |0 |  |
#31 32 33 34 35 36 37 38           39 40 41                              42 
#  |  |  |  |  |  |  |  |210-258-2018|  |T |SABRE TRAVEL 1 EAST KIRKWOOD TX|
#43 44 45 46 47 48 49 50 51 52       53 54 55         56         57         
#  |  |  |  |  |D |  |  |  |  |76920558|0 |  |1330473683|1330473683|
#        58 59        60         61      62      63 64      65     66  67
#1330473684|0|1330473699|2147483647|1102985|1125056|0 |1312869|HOFHHH|HDQ|
#           68
#45781433/E0MA

  if ($fields_ifp[56] && ($fields_ifp[56] < $target_tmdate)) {
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


