#!/bin/perl
#*TITLE - %M% - Perl script to email rejected message count and example - %I%
#*SUBTTL Preface, and environment
#
#  (]$[) %M%:%I% | CDATE=%U% %G%
#
#       Copyright (C) 2000 Pegasus Solutions
#             All Rights Reserved
#

# Set Environment variable USW_GMT to Y to force GMT times.
$ENV{USE_GMT}="Y";

$rmlogfile = "FALSE";
$PID = getppid;
$| = 1;

#use integer;

################### 
###### Base directories
###################
$RUNDIR = "/unload/mikew/chainrej";
if ($ARGV[1]) {
  $LOGDIR = $ARGV[1];
}
else {
  $LOGDIR = "/usw/offln/daily";
}
$COMPRESSEDLOGDIR = "/loghist/rej";
$RCPDIR = "/home/web/http/htdocs/prod/chainrej";
$RCPBOX = "sundev";
$RCPACT = "web";

$mailaddr = "mike.watson\@pegs.com";

##############
######  Temporary files used by this script
##############
$ulgout = "${RUNDIR}/tmp.ulgout$PID";
$ulginject = "${RUNDIR}/tmp.ulginject$PID";

sub barf;
sub cleanup;

system("mkdir $RUNDIR 2>/dev/null");
chdir $RUNDIR;

# set ytime to be time (in seconds) of this time yesterday
$ytime = time - 60*60*24;
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday) = localtime($ytime);

# year is number of years since 1900, so we need to mod by 100
$year = $year % 100;

if ($ARGV[0]) {
  $date = $ARGV[0];
  $mon = substr($date, 0, 2);
  $mday = substr($date, 2, 2);
  $year = substr($date, 4, 2);
  #date is mmddyy
  $printdate = sprintf("%02d/%02d/%02d", $mon, $mday, $year);
  $monyear = sprintf("%02d%02d", $mon, $year);
}
else {
  #date is mmddyy
  $date = sprintf("%02d%02d%02d", $mon + 1, $mday, $year);
  $printdate = sprintf("%02d/%02d/%02d", $mon + 1, $mday, $year);
  $monyear = sprintf("%02d%02d", $mon + 1, $year);
}

# Create symaphore file.
$chnrej_no = "${RUNDIR}/chainrej_$date.NOTOK";
system "/bin/touch $chnrej_no";


#cleanup;
exit(0);

# subroutine to send fatal error msgs through email
sub barf {
  my ($problemmsg, @stuff) = @_;
  open MAILPIPE, "| mailx -s 'chainrej error message' $mailaddr"
    or die "Error opening mail pipe: $!";
  print MAILPIPE "$printdate\n";
  print MAILPIPE $problemmsg;
  close MAILPIPE or die "Error closing mail pipe: $!";
  exit 1;
}

# subroutine to clean up temporary files
sub cleanup {
  system("rm -f $chnrej_no");
}
