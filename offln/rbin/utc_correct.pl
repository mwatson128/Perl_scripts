#!/usr/local/bin/perl
use Time::Local;

# Directory where work is done
$workdir = "/uswsup01/research/mwatson";
$sumdir = "/uswsup01/research/per_sum";

chdir $workdir;

if ($ARGV[0]) {
  $month_day = $ARGV[0];
}
else {
  print "Give month and day as argument! \n";
}

foreach $i (00..23) {
  if (10 > $i) {
    $hr = "0$i";
  }
  else {
    $hr = "$i";
  }

  $cur_file = "per" . $month_day . $hr . ".sum";
  $zip_cur_file = "per" . $month_day . $hr . ".sum.gz";
  $out_file = "per" . $month_day . $hr . ".out";

  if (-e "$sumdir/$zip_cur_file") {
    system("cp $sumdir/$zip_cur_file .");
    system("gunzip $workdir/$zip_cur_file");
  }
  elsif (-e "$sumdir/$cur_file") {
    system("cp $sumdir/$zip_cur_file $workdir");
  }
  die "can't find file!\n" if (!(-e "$cur_file"));

  # Open perf update file
  open SUM, "< $cur_file" or 
    die "Can't open $workdir/$cur_file for writing.\n";
  open OFP, "> $out_file";

  while ($line = <SUM>) {
    # Split out MSN into qid, tstamp and seq
    @parts = split /\|/, $line;
    $parts[0] += 25200;   # Add 7 hours in sec to number.
    $output = join("|", @parts);
    printf OFP "$output";
  }
  close SUM;
  close OFP;

  system("rm $cur_file");
  system("mv $out_file $cur_file");
  system("gzip $cur_file");

}

