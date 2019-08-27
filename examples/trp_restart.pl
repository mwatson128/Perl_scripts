#!/bin/perl

################
# Variables
################
chomp ($zone = `uname -n`);
$wdir = "/${zone}/uat";
#$maillist = "pedpg\@pegs.com";
$maillist = "mike.watson\@pegs.com";
$kps = "/uswuat01/knet/knet2.2.6.28/runtime/bin/kps";

# Usage statement.
$usage_s = "Usage: trp_restart.pl <kps process> \n";
$usage_s .= "  This script will check a TRP status and restart \n";
$usage_s .= "  if found down. \n";
$usage_s .= "  Example:  trp_restart.pl GWP (-TRP3A is automatically appended)\n";
 
$got_na = 0;
$email_needed = 0;

# If ran with no args give usage and quit
if (defined $ARGV[0]) {
  chomp $ARGV[0];
  if ($ARGV[0] =~ /-/) {
    $inproc_id = $ARGV[0];
    @arg_parts = split /-/, $ARGV[0];
    $trp_arg = lc($arg_parts[0]);
    $uc_trp_arg = uc($arg_parts[0]);
    $kprocid = uc($inproc_id);
  }
  else {
    $trp_arg = lc($ARGV[0]);
    $uc_trp_arg = uc($ARGV[0]);
    $kprocid = $uc_trp_arg . "-TRP3A";
  } 
  $logf = ">> ${wdir}/${uc_trp_arg}-restart.log";
  chdir $wdir;
}
else {
  print $usage_s;
  exit;
}
  
chomp ($tdcmd = qx(date +"%b/%e/%Y %T"));
open LOG, $logf;

# Put in a check for kivanet down and email out if it happens
if (`$kps 2>&1 | grep "KivaNet isn't running"`) {
  print LOG "[ $tdcmd Kivanet isn't up, nothing we can do]";
  print LOG "\n";
  close LOG;
  exit;
}

# Find out if the TRP process is up.
if (!`$kps 2>/dev/null | grep $kprocid`) {
  print LOG "[ $tdcmd $kprocid was found down."; 

  # Get the startup file name.
  $rv = qx(grep -l $kprocid /${zone}/uat/config/strp*);
  chomp $rv;

  # if down, try to restart.
  print LOG " Restarting, will wait for it to come up ]";
  qx($rv); 

  # wait 60 seconds and if still down, try again.
  sleep 10;
  if (!`$kps 2>/dev/null | grep $kprocid`) {
    chomp ($tdcmd = qx(date +"%b/%e/%Y %T"));
    print LOG "[ $tdcmd still down.  Second attemp to bring up. ";
    print LOG "Restarting, will wait for it to come up ]";
    qx($rv); 
      
    # wait 60 more seconds and give up if not up.
    sleep 10;
    if (!`$kps 2>/dev/null | grep $kprocid`) {
      chomp ($tdcmd = qx(date +"%b/%e/%Y %T"));
      print LOG "[ $tdcmd still down. No more attempts made]";
      print LOG "\n";
      close LOG;
      exit;
    }
    else {
      print LOG " $tdcmd Now process back up. \n";
      print LOG "\n";
      close LOG;
      exit;
    }
  }
  else {
    print LOG "[ $tdcmd Now process back up. ]";
    print LOG "\n";
    close LOG;
    exit;
  }
}
else {
  print LOG "[ $tdcmd \t Process is up ]";
  print LOG "\n";
}

close LOG;
exit;
