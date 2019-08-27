#!/usr/local/bin/perl

use Getopt::Long;
sub usage();

$help_cmd = 0;
$rm_all = 0;

GetOptions (
  'c|chn=s' => \$chn,
  'h|help' => \$help_cmd,
  'f|file=s' => \$filename,
  'r|rtdir=s' => \$user_rtdir,
  'd|day=s' => \$cmd_day
);

$zone = `uname -n`;
chomp($zone);
$day = `env TZ=GMT0 date '+%d'`;
chomp($day);

if ($help_cmd eq "1") {
  usage();
  exit();
}
elsif ($chn eq "") {
  usage();
  exit();
}
elsif ($cmd_day eq "") {
  usage();
  exit();
}

# define filename
if ($filename eq "" && $cmd_day eq "") {
  # will convert day to int, dropping leading zero
  $day += 0;
  $filename = "rtlog" . $day;
  $monday = `env TZ=GMT0 date '+%m%d'`;
  chomp($monday);
}
if ($filename eq "" && $cmd_day ne "") {
  $mon = `env TZ=GMT0 date '+%m'`;
  chomp $mon;
  $monday = $mon . $cmd_day;

  # will convert day to int, dropping leading zero
  $cmd_day += 0;
  $filename = "rtlog" . $cmd_day;
}

# Using the LOGNAME env variable to set default values
if ($ENV{LOGNAME} =~ /^usw$|^prod_sup$/) {
  $rtdir = "/$zone/logs/rtlogs/";
}
elsif ($ENV{LOGNAME} eq "uswrpt") {
  $mony = `env TZ=GMT0 date '+%m%y'`;
  chomp $mony;
  $supdir = "/$zone/loghist/uswprod01/rtlogs/" . $mony;
  #qx(cp ${supdir}/${filename}* .);
  #qx(gunzip $filename);
  $rtdir = "./";
  $rm_all = 1;
}
else {
  $rtdir = "./";
}

if (defined $user_rtdir) {
  $rtdir = $user_rtdir . "/";
}

$MSN = 0;
$GDS = 1;
$SGA = 2;
$CHN = 3;
$MSGT = 4;
$ORGT = 5;
$ARVT = 6;

$total_pals = 0;
$total_aals = 0;
$total_rpin = 0;
$total_book = 0;
$total_all = 0;
$total_answer = 0;

$tmpfile = "${chn}_rtfile";
#`grep $chn ${rtdir}${filename} > $tmpfile`;
#@file_cont = `grep $chn ${rtdir}${filename}`;
@file_cont = `cat $tmpfile`; 

foreach $ln (@file_cont) {
  chomp $ln;
  print "line is $ln\n";

# Looks like:
#           0   1        2       3        4             5        6       7
#[USWPRODCE09] <= 03/08/12 00:00:01 (HDJ-A2) EX(A3IPCTTM): Context timeout:
#       8        9      10      12      14                   15       16
#03/07/12 23:59:46 HRS:SC1  GDS:HD  SGA:00 msgno:1210F57F6713A7 MTP:RPIN =>

  if ($ln =~ /Context timeout/) {
    @flds = split /\s/, $ln;
    ($title, $msg_chn) = split /:/, $flds[10];

    if ($chn eq $msg_chn) {
      ($title, $msn) = split /:/, $flds[15];
      ($title, $msgtype) = split /:/, $flds[16];
      ($title, $gds) = split /:/, $flds[12];
      ($title, $sga) = split /:/, $flds[14];
      $orgtime = $flds[8] . " " . $flds[9];
      $msg_hash{$msn}[$MSN] = $msn;
      $msg_hash{$msn}[$GDS] = $gds;
      $msg_hash{$msn}[$SGA] = $sga;
      $msg_hash{$msn}[$CHN] = $chn;
      $msg_hash{$msn}[$MSGT] = $msgtype;
      $msg_hash{$msn}[$ORGT] = $orgtime;
      #$msg_hash{$msn}[$ARVT] = "Message not recieved";

   }
  }

#  Now find when the message was finally recieved.
#[USWPRODCE08] <= 03/08/12 00:00:34 (SC1-A2) EX(A3IPCTXE): Cannot find USW
#message number 0C14F57F5B0ADD in context. =>

  if ($ln =~ /Cannot find/) {
    @flds = split /\s/, $ln;

    if ($chn eq $msg_chn) {
      $arvtime = $flds[2] . " " . $flds[3];
      print "MSN is $flds[11] \n";
      $msg_hash{$flds[11]}[$ARVT] = $arvtime;
      $total_answer += 1;
    }
  }
}

# Now rearrange them in chronological order
foreach $elem (sort keys %msg_hash) {
  $new_key = $msg_hash{$elem}[$ORGT] . $elem;
  $hash_bydate{$new_key}[$MSN] = $msg_hash{$elem}[$MSN];
  $hash_bydate{$new_key}[$GDS] = $msg_hash{$elem}[$GDS];
  $hash_bydate{$new_key}[$SGA] = $msg_hash{$elem}[$SGA];
  $hash_bydate{$new_key}[$CHN] = $msg_hash{$elem}[$CHN];
  $hash_bydate{$new_key}[$MSGT] = $msg_hash{$elem}[$MSGT];
  $hash_bydate{$new_key}[$ORGT] = $msg_hash{$elem}[$ORGT];
  $hash_bydate{$new_key}[$ARVT] = $msg_hash{$elem}[$ARVT];
}

open OFP, "> ${chn}_timeouts_${monday}.csv";
printf OFP "Message number, GDS(ARS), SGA, HRS(CHN), Message Type, Origin time, Response time\n";
foreach $elem (sort keys %hash_bydate) {

  next if ($hash_bydate{$elem}[$MSN] eq "");
  if ($hash_bydate{$elem}[$MSGT] eq "PALS") {
    $total_pals += 1;
  }
  if ($hash_bydate{$elem}[$MSGT] eq "AALS") {
    $total_aals += 1;
  }
  if ($hash_bydate{$elem}[$MSGT] eq "RPIN") {
    $total_rpin += 1;
  }
  if ($hash_bydate{$elem}[$MSGT] eq "BOOK") {
    $total_book += 1;
  }
  $total_all += 1;

  printf OFP "$hash_bydate{$elem}[$MSN],";
  printf OFP "$hash_bydate{$elem}[$GDS],";
  printf OFP "$hash_bydate{$elem}[$SGA],";
  printf OFP "$hash_bydate{$elem}[$CHN],";
  printf OFP "$hash_bydate{$elem}[$MSGT],";
  printf OFP "$hash_bydate{$elem}[$ORGT],";
  if ($hash_bydate{$elem}[$ARVT]) {  
    printf OFP "$hash_bydate{$elem}[$ARVT]";
  }
  else {
    printf OFP "message not returned";
  }
  printf OFP "\n";
}

printf OFP "\n";

$total_noan = $total_all - $total_answer;

printf OFP "Total PALS messages timed out,$total_pals\n";
printf OFP "Total AALS messages timed out,$total_aals\n";
printf OFP "Total RPIN messages timed out,$total_rpin\n";
printf OFP "Total BOOK messages timed out,$total_book\n";
printf OFP "Total messages with no answer,$total_noan\n";
printf OFP "Total timed out messages     ,$total_all\n";
close OFP;

print "output is in ${chn}_timeouts_${monday}.csv \n";
#`rm $tmpfile`;
if ($rm_all) {
  #`rm ${rtdir}${filename}`;
}


sub usage() {

  print "Usage: timeout_trace.pl <options> -d and -c are required\n";
  print "  Will find CHN's timeouts in the days rtlog and print \n";
  print "  them in comma separated form to be sent to the customer. \n";
  print "  Output goes to a file named <CHN>_timeouts_<DAY><MON>.csv. \n";
  print "  Options:\n";
  print "  -(c|chn) CHN        - any valid USW chain code. \n";
  print "  -(h|help)           - Print this help message \n";
  print "  -(f|file) rtlogfile - file to use instead of regular rtlog\n";
  print "  -(r|rtdir) log dir  - directory to use instead of default\n";
  print "  -(d|date) <0-31>    - day to use, only for past one month\n\n";
}
