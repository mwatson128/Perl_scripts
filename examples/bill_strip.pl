#!/bin/perl
#
# Script to run daily billing and glean specific totals.
#

# Go through allready printed billing reports and grep out the 
# real important stuff.

$ARGC = @ARGV;
if ( $ARGC < 1) {

  @files = qx(ls -1 *.bil);

}
elsif ( $ARGC == 1) {

  @files = qx(ls -1 $ARGV[0]*);

}
else {

  print "Usage: daybill.pl [DATE Day]\n";
  print "   DATE = Date to run reports for. in mm/dd/yy format.\n";
  print "   Day = 3 letter day of the Week ie Mon.\n";
  print "   All other command line arguments get this message.\n";
  print "Generate daily billing and append to existing file.\n";
  print "Configuration is in maillist.cfg.\n";
  exit;
}

printf " DATE  GDS   HRS     Type A\n";

foreach $c_file ( @files ) {

  # Need to get newline out of chain.
  chomp($c_file);

  @bill_report = qx(cat $c_file); 
 

  # these are the lines from the billing that we need.
  # so grab the numbers from lines 45 and 58.
  $bill_report[3] =~ /(\w)/;
  print reports[3];
  $bill_all[0] = $1;
  # GDS
  @parts = split /:/,$bill_report[5];
  chomp $parts[$#parts];
  $bill_all[1] = $parts[$#parts];
  # HRS
  @parts = split /:/,$bill_report[6];
  chomp $parts[$#parts];
  @charac = split /\|/, $parts[$#parts];

  $bill_all[2] = $charac[0] . $charac[1];
  # Type A bookings
  $bill_report[45] =~ /(-*\d+)/;
  $bill_all[3] = $1;
  # Type B bookings
  $bill_report[58] =~ /(-*\d+)/;
  $bill_all[4] = $1;  

  printf " %10s %10s %8d %8d   \n", $bill_all[0], $bill_all[1], $bill_all[2], 
         $bill_all[3];
}


#  print LOG "      Starting to email reports: ", `/bin/date`, "\n";
#
#  foreach $name_split ( sort( keys %config_file )) {
#
#    @user = split /\:/, $config_file{$name_split};
# 
#    @tmp = split / /, $user[0];
#    $name = $tmp[0] . "_" . $tmp[1];
#
#    $MAILFILE = ">tmp.$name";
#  $bill_report[45] =~ /(-*\d+)/;
#  $bill_all[2] = $1;
#  $bill_report[58] =~ /(-*\d+)/;
#  $bill_all[3] = $1;  
#
#  printf "------------- %7d   %6d   ", $bill_all[1], $bill_all[0];
#  print "\n";
#}
#
#
#  print LOG "      Starting to email reports: ", `/bin/date`, "\n";
#
#  foreach $name_split ( sort( keys %config_file )) {
#
#    @user = split /\:/, $config_file{$name_split};
# 
#    @tmp = split / /, $user[0];
#    $name = $tmp[0] . "_" . $tmp[1];
#
#    $MAILFILE = ">tmp.$name";
#    open MAILFILE or die "Can't open output file: $MAILFILE";
#    print MAILFILE "            $DATE Daily billing summary for ", 
#                   $user[0], "\n\n";
#
#    $mailname = "";
#    @mailnames = split /,/, $user[1];
#    if ($#mailnames < 0 ) {
#      foreach $address (@mailnames) {
#        $mailname .= $address;
#	$mailname .= " ";
#      }
#    }
#    else {
#      $mailname = $mailnames[0];
#    }
#
#    for ($i = 2; $i <= $#user; $i++) {
#    
#      @ch_name = split /\|/, $user[$i];
#      $num_ch = @ch_name;
#      if ($num_ch > 1) {
#        $fname = lc $ch_name[0];
#        $fname .= "con";
#      }
#      else {
#        $fname = lc $ch_name[0];
#      }
#
#      @chns_1 = split /\|/, $user[$i];
#      $chn_cnt = @chns_1;
#      print MAILFILE "               Daily Booking Activity for ";
#      if ($chn_cnt > 15) {
#        for ($i = 0; $i < $chn_cnt; $i++) {
#	  if ($i == 14 or $i == 40 or $i == 80) { 
#	    print MAILFILE "\n\t$chns_1[$i]|";
#	  }
#	  else {
#	    print MAILFILE "$chns_1[$i]|";
#	  }
#	}
#        print MAILFILE "\n\n";
#      }
#      else {
#      	print MAILFILE "$user[$i]",  "\n\n";
#      }
#
#      print MAILFILE "               Status     Net ", "\n";
#      printf MAILFILE "                Segs    Bookings %7s%7s%7s%7s%7s%7s%7s\n", 
#                     "AA", "UA", "1P", "1A", "WB", "MS", "HD";
#      $chn_file = qx(tail -14 /usw/reports/daily/billing/data/"$fname".bil);
#      print MAILFILE $chn_file, "\n\n";
#    }
#    close MAILFILE;
#
#    qx(cat tmp.$name | mailx -s "$user[0] Daily Billing for $DATE" $mailname);
#    qx(rm tmp.$name);
#
#  }
#
#}
#

