#!/bin/perl
#*TITLE - lg_clean.pl - Perl script to check Database Space Utilization - 1.23
#*SUBTTL Preface, and environment
#
#  (]$[) lg_clean.pl:1.23 | CDATE=04/22/13 21:55:22
#
#
#          Copyright (C) 2002 Pegasus Solutions, Inc.
#                    All Rights Reserved
#
#

use Getopt::Std;
use Time::Local;

# Subs

sub del;
sub comp;
sub usage;

# GLOBALS
# Set this number of days worth of log files you want to keep, in seconds.

# For /loghist in test
$perdays =  3 * 86400;	#  3 days
$p2rdays =  2 * 86400;	#  2 days
$rptdays =  7 * 86400;	#  7 days
$rtlogdays =  7 * 86400;  # 7 days

# Grab command line stuff
getopts('lh');

$ARGC = @ARGV;
if ( $ARGC < 1 ) {
  usage();
}
elsif ($ARGC == 1 && $ARGV[0] eq "zip") {
  $zip = TRUE;
}
elsif ($ARGC == 1 && $ARGV[0] eq "del") {
  $del = TRUE;
}
elsif ($ARGC == 1 && $ARGV[0] eq "help") {
  usage();
}
elsif ($ARGC == 2) {
  if ($ARGV[0] eq "zip" || $ARGV[1] eq "zip") {
    $zip = TRUE;
  }
  if ($ARGV[0] eq "del" || $ARGV[1] eq "del") {
    $del = TRUE;
  }
}
else {
  usage();
}

# Print help if ask to...
if ($opt_h) {
  usage();
}

$TPE1 = "uswprod01";
$TPE2 = "uswprod02";
$TPE3 = "uswprod03";
$TPE4 = "uswprod04";
$PERALL = "per_all";
$RPTALL = "rpt_all";
$REJALL = "rej_all";
$SD = "uswsd01";
$HD = "/uswsup01/loghist";

# do system-dependent things.
@zip_targets = ("$HD/$TPE1/p2r", "$HD/$TPE1/per", "$HD/$TPE1/rej", 
		"$HD/$TPE2/p2r", "$HD/$TPE2/per", "$HD/$TPE2/rej", 
		"$HD/$TPE3/p2r", "$HD/$TPE3/per", "$HD/$TPE3/rej",
		"$HD/$TPE4/p2r", "$HD/$TPE4/per", "$HD/$TPE4/rej",
		"$HD/$PERALL", "$HD/$RPTALL", "$HD/$REJALL", 
		"$HD/$TPE1/rtlogs", "$HD/$SD/rtlogs");
@per_targets = ("$HD/$TPE1/per", "$HD/$TPE1/trc",
		"$HD/$TPE2/per", "$HD/$TPE2/trc",
		"$HD/$TPE3/per", "$HD/$TPE3/trc",
		"$HD/$TPE4/per", "$HD/$TPE4/trc",
		"$HD/$PERALL");
@p2r_targets = ("$HD/$TPE1/p2r", "$HD/$TPE2/p2r", 
		"$HD/$TPE3/p2r", "$HD/$TPE4/p2r");
@rpt_targets = ("$HD/$TPE1/rpt", "$HD/$TPE1/co", "$HD/$TPE1/rej",
		"$HD/$TPE2/rpt", "$HD/$TPE2/co", "$HD/$TPE2/rej",
		"$HD/$TPE3/rpt", "$HD/$TPE3/co", "$HD/$TPE3/rej",
		"$HD/$TPE4/rpt", "$HD/$TPE4/co", "$HD/$TPE4/rej");
@rtlog_targets = ("$HD/$TPE1/rtlogs", "$HD/$SD/rtlogs");

$now = time;
$gzday = $now - 86400;
$perdel = $now - $perdays;
$p2rdel = $now - $p2rdays;
$rptdel = $now - $rptdays;
$rtlogdel = $now - $rtlogdays;


#*SUBTTL Main
#
# This is a log compression and deletion script that will compress using
# gzip, logs that are older than today and delete logs that are older than
# ${keepday} old.
#

if ($del) {
  del();
}
if ($zip) {
  comp();
} 
  

#*SUBTTL usage
#
# Print a usage statement and exit.
#
sub usage {

  print "Usage: lg_gzip.pl [-l] [-h] zip del\n";
  print "   -l  list the files to change, but don't change anything.\n";
  print "   -h  print a usage statement and exit.\n";
  print "   zip just do the zip step \n";
  print "   del just do the del step \n";
  print "    For full functionality you need to list both zip and del\n";
  print "This program looks for files of a certain age and gzips them \n";
  print "or deletes them, depending on their age.\n";
  exit;

}

#*SUBTTL del
#
# Delete the files that are more than keepdays old.
#
sub del {

  # Delete per Targets
  foreach $targets (@per_targets) {

    @files = qx(ls $targets);
    foreach $file (@files) {
      chomp $file;

      if ($file =~ m/per(\d\d)(\d\d)(\d\d)/ ) {

        next if (11 < $_ || 0 > $_);

        $filemon = $1;
        # minus the month to make it zero based.
        $filemon--;
        $fileday = $2;

        # Get the year now. 
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($now);

        # If the month from the file is greater than the current month,
        # it could only mean we're straddling the year boundary. Make
        # the year of the file last year. 
        if ($filemon > $mon) {
          $year--;
        }
       
        # Lets use 00:00:00 GMT for hour:min:sec.
        $filehour = 00;
        $filemin  = 00;
        $filesec  = 00;
       
        $fileutc = timelocal($filesec,$filemin,$filehour,$fileday,
                             $filemon,$year);
             
        # If the UTC fo the file is less than the delday, delete it
        if ($fileutc < $perdel) {
        
          # If the -l option is given, print instead 
          if ($opt_l) {
            print "Going to delete $targets/$file\n";
          }
          else {
            qx(/usr/bin/rm -rf $targets/$file);
          }
        } 
      }
    }
  } # End of delete PER targets

  # Delete p2r Targets
  foreach $targets (@p2r_targets) {

    @files = qx(ls $targets);
    foreach $file (@files) {
      chomp $file;
 
      # If file has a date embeded, usw it.
      if ($file =~ m/p2r(\d\d)(\d\d)(\d\d)/ ) {

        next if (11 < $_ || 0 > $_);
        $filemon = $1;
        # minus the month to make it zero based.
        $filemon--;
        $fileday = $2;

        # Get the year now. 
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($now);

        # If the month from the file is greater than the current month,
        # it could only mean we're straddling the year boundary. Make
        # the year of the file last year. 
        if ($filemon > $mon) {
          $year--;
        }
     
        # Lets use 00:00:00 GMT for hour:min:sec.
        $filehour = 00;
        $filemin  = 00;
        $filesec  = 00;
     
        $fileutc = timelocal($filesec,$filemin,$filehour,$fileday,
                             $filemon,$year);
           
        # If the UTC of the file is less than the delday, delete it
        if ($fileutc < $p2rdel) {
      
          # If the -l option is given, print instead 
          if ($opt_l) {
            print "Going to delete $targets/$file\n";
          }
          else {
            qx(/usr/bin/rm -rf $targets/$file);
          } 
        } # End if UTC check 
      } # End file has a date embeded
    } # End Each file in P2R directory
  } # End of delete P2R targets

  # Delete rpt Targets
  foreach $target (@rpt_targets) {

    @files = qx(ls $target);
    foreach $file (@files) {
      chomp $file;

      if ($file =~ m/(\d\d)(\d\d)(\d\d)/ ) {

        next if (11 < $_ || 0 > $_);
        $filemon = $1;
        # minus the month to make it zero based.
        $filemon--;
        $fileday = $2;

        # Get the year now. 
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($now);

        # If the month from the file is greater than the current month,
        # it could only mean we're straddling the year boundary. Make
        # the year of the file last year. 
        if ($filemon > $mon) {
          $year--;
        }
       
        # Lets use 00:00:00 GMT for hour:min:sec.
        $filehour = 00;
        $filemin  = 00;
        $filesec  = 00;
       
        $fileutc = timelocal($filesec,$filemin,$filehour,$fileday,
                             $filemon,$year);
             
        # If the UTC of the file is less than the delday, delete it
        if ($fileutc < $rptdel) {
        
          # If the -l option is given, print instead 
          if ($opt_l) {
            print "Going to delete $target/$file\n";
          }
          else {
            qx(/usr/bin/rm -rf $target/$file);
          }
        } 
      }
    }
  } # End of delete RPT targets.

  # Delete RTLOG Targets
  foreach $target (@rtlog_targets) {

    @files = qx(ls $target/????/*);

    foreach $file (@files) {
      chomp $file;

      if ($file =~ m/\/(\d\d)(\d\d)\/rtlog(\d+)/ ) {

        next if (11 < $_ || 0 > $_);
        $filemon = $1;
        # minus the month to make it zero based.
        $filemon--;
        $fileday = $3;

        # Get the year now.
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($now);

        # If the month from the file is greater than the current month,
        # it could only mean we're straddling the year boundary. Make
        # the year of the file last year.
        if ($filemon > $mon) {
          $year--;
        }

        # Lets use 00:00:00 GMT for hour:min:sec.
        $filehour = 00;
        $filemin  = 00;
        $filesec  = 00;

        $fileutc = timelocal($filesec,$filemin,$filehour,$fileday,
                             $filemon,$year);

        # If the UTC of the file is less than the delday, delete it
        if ($fileutc < $rtlogdel) {

          # If the -l option is given, print instead
          if ($opt_l) {
            print "Going to delete $file\n";
          }
          else {
            qx(/usr/bin/rm -rf $file);
          }
        }
      }
    }
  } # End of delete RTLOG targets.

}

#*SUBTTL comp
#
# Compress using gzip the files that are older than today.
#
sub comp {

  foreach $target (@zip_targets) {
    
    @files = qx(ls $target);
    foreach $file (@files) {
      chomp $file;
      next if ( $file =~ m/gz$|Z$/ ) ; # skip already gziped files

      if ($file =~ m/(\d\d)(\d\d)(\d\d)/ ) {

	# The next 20 lines or so are converting the time stamp in the 
	# file name to a UTC time.

        $filemon = $1;
	# minus the month to make it zero based.
	$filemon--;
	$fileday = $2;

        # Get the year now. 
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($now);

        # If the month from the file is greater than the current month,
	# it could only mean we're straddling the year boundary. Make
	# the year of the file last year. 
	if ($filemon > $mon) {
	  $year--;
	}
	
	# Lets use 00:00:00 GMT for hour:min:sec.
	$filehour = 00;
	$filemin  = 00;
	$filesec  = 00;

	$fileutc = timelocal($filesec,$filemin,$filehour,$fileday,
	                     $filemon,$year);
        
	# If the UTC fo the file is less than the gzday, gzip it
	if ($fileutc < $gzday) {

	  # If the -l option is given, print instead 
	  if ($opt_l) {
	    print "Going to gzip $target/$file\n";
	  }
	  else {
            qx(gzip -f $target/$file);
          }
        }
      }
    }
  }
}
