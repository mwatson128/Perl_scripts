#!/bin/perl

if ($ARGV[0]) {
  $date = $ARGV[0];
}
else {
  printf "Need date as argument, joiner.pl 120411 \n";
  exit;
}

$rej_dir = "/uswsup01/loghist/uswprod01/rej/";
$rej_file = $rej_dir . "rej" . $date . ".lg";
$rejgz_file = $rej_dir . "rej" . $date . ".lg.gz";
$rej_join = "/uswsup01/usw/offln/bin/rpt_join";
$arc_dir = "/uswsup01/loghist/rej_all/";
$rundir = "/uswsup01/usw/offln/daily/";
chdir $rundir;

$LOG =">> /uswsup01/support/ktwist.join.log";
open LOG;  # or die "can't opne log file\n";

$dt = qx(/bin/date);
chomp $dt;
print LOG "\n\n>>--- RPT_JOIN:  Starting joiner $dt --<<\n";

# List of tpe's, add here if one is added.
@usw_tpes = ("uswprod01",
             "uswprod02",
             "uswprod03");

# start an arg list for rpt_join
$jn_args = "-o rej${date}.lg ";
$rm_cmd = "rm -f ";
$tpe_cnt = 1;

foreach $tpe (@usw_tpes) {

  print LOG " >--- RPT_JOIN:  $tpe run, cp and gunzip files  --<\n";
  # Get log files for this CE
  # qx (cp /uswsup01/loghist/${tpe}/rpt/rpt${date}.lg* $rundir);
  # gunzip the rej and rename 
  #  if ($tpe eq "uswprod01") {
    qx (cp $rej_file $rundir) || qx (cp $rejgz_file $rundir);
    qx (gunzip rej*.gz 2>>/dev/null);
    qx (mv ${rundir}rej${date}.lg  ${rundir}rej${date}_${tpe_cnt}.lg);
  #  }

  # gunzip the rpt and rename
  #qx (gunzip ${rundir}rpt${date}.lg*);
  #qx (mv ${rundir}rpt${date}.lg ${rundir}rpt${date}_${tpe_cnt}.lg);

  print LOG " >--- REJ_JOIN:  $tpe run, adding rej${date}_${tpe_cnt}.lg to args  --<\n";
  # Add this one to the rpt_join arguments
  $jn_args .= "-i ${rundir}rej${date}_${tpe_cnt}.lg ";

  # Add this one to delete list for clean up.
  $rm_cmd .= " ${rundir}rej${date}_${tpe_cnt}.lg";

  $tpe_cnt++;
}

$dt = qx(/bin/date);
chomp $dt;
print LOG "\n>>--- REJ_JOIN:  Started  running joiner $dt --<<\n";
qx ($rej_join $jn_args ${LOG});

$dt = qx(/bin/date);
chomp $dt;
print LOG "\n>>--- REJ_JOIN:  Finished running joiner $dt --<<\n";
close LOG;

# Remove left over files now.
qx($rm_cmd);

$arcfile = $arc_dir . "rej" . $date . ".lg";
$arcfilegz = $arc_dir . "rej" . $date . ".lg.gz";

# Archive the rpt file once joined.
if (!(-e $arcfile ) && 
    !(-e $arcfilegz)) {
  qx (cp ${rundir}rej${date}.lg ${arc_dir});
  qx (gzip ${arc_dir}rej${date}.lg);
}


