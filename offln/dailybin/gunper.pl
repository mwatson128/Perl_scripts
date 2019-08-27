#!/bin/perl
# Make sure the loghist PER files are uncompressed
#
#  (]$[) gunper.pl:1.5 | CDATE=10:19:39 01/18/08
#

$zone = `uname -n`;
chomp $zone;
$lgper_dir = "/$zone/loghist/uswprod01/per";

$rundate = $ARGV[0];
chomp $rundate;

foreach $i (00..23) {
    if (10 > $i) {
      $hr = "0$i";
    }
    else {
      $hr = "$i";
    }

    # test for existance of the logfiles, before putting them into the list.
    # if some are missing, keep a record of which ones.
    my($tempf) = "${lgper_dir}/per${rundate}${hr}.lg";
    my($gztemp) = "${lgper_dir}/per${rundate}${hr}.lg.gz";
    if (-f "${tempf}")  {
      $lgper_file{$hr} = "lg";
    }
    elsif (-f "${gztemp}") {
      $lgper_file{$hr} = "gz";
    }
    else {
      $lgper_file{$hr} = "ms";
    }
}

foreach $pf (sort keys %lgper_file) {
  
  $ext = $lgper_file{$pf};
  $pfile = "${lgper_dir}/per${rundate}${pf}.lg";

  if ($ext eq "ms") {
    print "File  is  missing: ${pfile}\n";
  }
  elsif ($ext eq "gz") {
    if ($rc = qx(/bin/gunzip $pfile)) {
      print "Gunzip on file $pfile failed with $rc\n";
    }
    else { 
      print "File gets gunziped: ${pfile}\n";
    }
  }
}
