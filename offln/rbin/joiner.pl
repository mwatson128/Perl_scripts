#!/bin/perl

if ($ARGV[0]) {
  $date = $ARGV[0];
}
else {
  printf "Need date as argument, joiner.pl 120411 \n";
  exit;
}

$rpt_join = "/uswsup01/usw/offln/bin/rpt_join";
$rpt_arc_dir = "/uswsup01/loghist/rpt_all/";
$rej_arc_dir = "/uswsup01/loghist/rej_all/";
$rundir = "/uswsup01/usw/offln/daily/";
chdir $rundir;

$LOG =">> /uswsup01/usw/offln/daily/joiner.log";
open LOG;  # or die "can't open log file\n";
select  LOG;
$| = 1;

$dt = qx(/bin/date);
chomp $dt;
print LOG "\n\n>>--- RPT_JOIN: Start $dt --<<\n";

# List of tpe's, add here if one is added.
@usw_tpes = ("uswprod01",
             "uswprod02",
             "uswprod03",
	     "uswprod04");

# start an arg list for rpt_join
$rptjn_args = "-o rpt${date}.lg ";
$rejjn_args = "-o rej${date}.lg ";
$rm_cmd = "rm -f ";
$rpt_fcnt = 1;
$rej_fcnt = 1;

foreach $tpe (@usw_tpes) {

  print LOG " >--- RPT_JOIN:  $tpe run, cp and gunzip files  --<\n";
  # Get log files for this CE
  qx (cp /uswsup01/loghist/${tpe}/rpt/rpt${date}.lg* $rundir);
  qx (cp /uswsup01/loghist/${tpe}/rej/rej${date}.lg* $rundir);

  # gunzip the rpt and rename
  qx (gunzip ${rundir}rpt${date}.lg*);
  qx (gunzip ${rundir}rej${date}.lg*.gz);

  @rpt_flist = `ls -1 ${rundir}rpt${date}.lg*`;
  @rej_flist = `ls -1 ${rundir}rej${date}.lg*`;
    
  foreach $rpt_f (@rpt_flist) {
    chomp $rpt_f;
    print LOG " >--- RPT_JOIN:  $tpe run, adding rpt${date}_${rpt_fcnt}.lg to args  --<\n";
    qx (mv $rpt_f ${rundir}rpt${date}_${rpt_fcnt}.lg);

    # Add this one to the rpt_join arguments
    $rptjn_args .= "-i ${rundir}rpt${date}_${rpt_fcnt}.lg ";

    # Add this one to delete list for clean up.
    $rm_cmd .= " ${rundir}rpt${date}_${rpt_fcnt}.lg";
    $rpt_fcnt++;
  }
    

  foreach $rej_f (@rej_flist) {
    chomp $rej_f;
    print LOG " >--- RPT_JOIN:  $tpe run, adding rej${date}_${rej_fcnt}.lg to args  --<\n"; 
    qx (mv $rej_f ${rundir}rej${date}_${rej_fcnt}.lg);

    # Add this one to the rej_join arguments
    $rejjn_args .= "-i ${rundir}rej${date}_${rej_fcnt}.lg ";

    # Add this one to delete list for clean up.
    $rm_cmd .= " ${rundir}rej${date}_${rej_fcnt}.lg";
    $rej_fcnt++;
  } 
}
  
print LOG " >--- RPT_JOIN: Finished making files, now join together ---<\n\n";

print "RPT_JOIN: $rpt_join $rptjn_args \n";

$dt = qx(/bin/date);
chomp $dt;
print LOG "\n >>--- RPT_JOIN:  Started  running joiner for RPT $dt --<<\n";
qx ($rpt_join $rptjn_args);

print "REJ_JOIN: $rpt_join $rejjn_args \n";
print LOG "\n >>--- REJ_JOIN:  Started  running joiner for REJ $dt --<<\n";
qx ($rpt_join $rejjn_args);

$dt = qx(/bin/date);
chomp $dt;
print LOG "\n >>--- RPT_JOIN:  Finished running joiner $dt --<<\n";
close LOG;

# Remove left over files now.
qx($rm_cmd);

$rptarcfile = $rpt_arc_dir . "rpt" . $date . ".lg";
$rptarcfilegz = $rpt_arc_dir . "rpt" . $date . ".lg.gz";
$rejarcfile = $rej_arc_dir . "rej" . $date . ".lg";
$rejarcfilegz = $rej_arc_dir . "rej" . $date . ".lg.gz";

# Archive the rpt file once joined.
if (!(-e $rptarcfile ) && 
    !(-e $rptarcfilegz)) {
  qx (gzip ${rundir}rpt${date}.lg*);
  qx (cp ${rundir}rpt${date}.lg* ${rpt_arc_dir});
  qx (gunzip ${rundir}rpt${date}.lg*.gz);
}

# Archive the rej file once joined.
if (!(-e $rejarcfile ) && 
    !(-e $rejarcfilegz)) {
  qx (gzip ${rundir}rej${date}.lg*);
  qx (cp ${rundir}rej${date}.lg* ${rej_arc_dir});
  qx (gunzip ${rundir}rej${date}.lg*.gz);
}


