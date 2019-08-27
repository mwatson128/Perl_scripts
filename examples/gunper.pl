#!/bin/perl

$lgper_dir = "/loghist/per";
#$lgper_dir = "/qa/logs/lg2";

$rundate = $ARGV[0];

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
    print "File  is  missing: $pfile\n";
  }
  elsif ($ext eq "lg") {
    print "File is not zipped: $pfile\n";
  }
  elsif ($ext eq "gz") {
    if ($rc = qx(/bin/gunzip $pfile)) {
      print "Gunzip on file $pfile failed with $rc\n";
    }
    else { 
      print "File gets gunziped: $pfile\n";
    }
  }
}



