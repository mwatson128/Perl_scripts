#!/bin/perl
#
# Script to run daily billing and glean specific totals.
#
#
# % mktrec{msn} = 
#    xp->logx.hrs, 
#    xp->logx.ars, 
#    xp->logx.traftype, 
#    xp->logx.pdm,
#    xp->logx.direction (default to "u"),
#    xp->logx.uswmsgnum, 
#    xp->logx.lniata, 
#    xp->logx.gmt, 
#    xp->logx.sigars,
#    xp->logx.distchtype,
#    xp->logx.actcode (default to "unk"),
#    xp->logx.statuscode (default to "unk"),
#    xp->logx.booksrc, 
#    xp->logx.corpacct, 
#    xp->logx.msgtime,
#    xp->logx.chainid, 
#    xp->logx.ctrlno, 
#    xp->logx.custacct,
#    xp->logx.guartype, 
#    xp->logx.gcctype, 
#    xp->logx.freqtrav[0],
#    xp->logx.indate, 
#    xp->logx.outdate, 
#    xp->logx.guestname,
#    (int)xp->logx.numadults, 
#    (int)xp->logx.numkids,
#    (int)xp->logx.numnights, 
#    (int)xp->logx.numpersons,
#    (int)xp->logx.numrooms,
#    xp->logx.gdspid, 
#    xp->logx.propid, 
#    xp->logx.propname,
#    xp->logx.rrprefix, 
#    xp->logx.roomrate, 
#    xp->logx.curcode,
#    xp->logx.reqroomrate, 
#    xp->logx.totalrmrtinc, 
#    xp->logx.tourno,
#    xp->logx.agentphone, 
#    xp->logx.bookphone,
#    xp->logx.adr1type, 
#    xp->logx.addr1,
#    xp->logx.adr2type, 
#    xp->logx.addr2,
#    xp->logx.propcity, 
#    xp->logx.roomtype,
#    xp->logx.confnum, 
#    xp->logx.cancelnum, 
#    xp->logx.bookedrate,
#    xp->logx.service, 
#    xp->logx.ratefreq,
#    xp->logx.rateplandesc, 
#    xp->logx.rateplan, 
#    xp->logx.rmtypecode,
#    (int)xp->logx.segnum (default to 1),
#    xp->logx.logtime, 
#    xp->logx.tfromars, 
#    xp->logx.ttohrs,
#    xp->logx.tfromhrs, 
#    xp->logx.ttoars
#

$ARGC = @ARGV;

if ( $ARGC == 1) {

  if (-f $ARGV[0]) {
    $INFILE = "< $ARGV[0]";
  }
  else {
    print "$ARGV[0], not a regular file.\n";
    print $ARGV[0];
    exit;
  }
}
elsif ( $ARGC > 1) {

  print "Usage: parse_mkt.pl <amf file>\n";
  print "   All other command line arguments get this message.\n";
  exit;
}

open INFILE or die "Can't open file $INFILE";

while (<INFILE>) {

  next if /^#|^$/;
  chomp;
  
  next if (/\|IPN/);

  if (($msg_msn) = $_ =~ m/MSN(\w+)\|/) {
    
    if (m/\|PHS(\w+)\|/) {
      $mktrec{$msg_msn}[0] = $1;
    }
    if (m/\|PAS(\w+)\|/) {
      $mktrec{$msg_msn}[1] = $1;
    }
    if (m/\|UTT(\w+)\|/) {
      $mktrec{$msg_msn}[2] = $1;
    }
    if (m/\|PDM(\w+)\|/) {
      $mktrec{$msg_msn}[3] = $1;
    }
    if (m/\|DIR(\w+)\|/) {
      $mktrec{$msg_msn}[4] = $1;
    }
    $mktrec{$msg_msn}[5] = $msg_msn;
    if (m/\|IAT(\w+)\|/) {
      $mktrec{$msg_msn}[6] = $1;
    }
    if (m/\|GMT(\w+)\|/) {
      $mktrec{$msg_msn}[7] = $1;
    }
    if (m/\|SGA(\w+)\|/) {
      $mktrec{$msg_msn}[8] = $1;
    }
    if (m/\|DCH(\w+)\|/) {
      $mktrec{$msg_msn}[9] = $1;
    }
    if (m/\|ACT(\w+)\|/) {
      $mktrec{$msg_msn}[10] = $1;
    }
    if (m/\|BST(\w+)\|/) {
      $mktrec{$msg_msn}[11] = $1;
    }
    if (m/\|BKS(\w+)\|/) {
      $mktrec{$msg_msn}[12] = $1;
    }
    if (m/\|CCN(\w+)\|/) {
      $mktrec{$msg_msn}[13] = $1;
    }
    if (m/\|TIM(\w+)\|/) {
      $msgtime = `/qa/uswbin/tstamp -h $1`;
      chomp $msgtime;
      $mktrec{$msg_msn}[14] = $msgtime;
    }
    if (m/\|CHN(\w+)\|/) {
      $mktrec{$msg_msn}[15] = $1;
    }
    if (m/\|CON(\w+)\|/) {
      $mktrec{$msg_msn}[16] = $1;
    }
    if (m/\|CUA(\w+)\|/) {
      $mktrec{$msg_msn}[17] = $1;
    }
    if (m/\|GUT(\w+)\|/) {
      $mktrec{$msg_msn}[18] = $1;
    }
    if (m/\|GCT(\w+)\|/) {
      $mktrec{$msg_msn}[19] = $1;
    }
    if (m/\|IFT(\w+)\|/) {
      $mktrec{$msg_msn}[20] = $1;
    }
    if (m/\|IND(\w+)\|/) {
      $mktrec{$msg_msn}[21] = $1;
    }
    if (m/\|OTD(\w+)\|/) {
      $mktrec{$msg_msn}[22] = $1;
    }
    if (m/\|NAM(\w+)\|/) {
      $mktrec{$msg_msn}[23] = $1;
    }
    if (m/\|NAD(\w+)\|/) {
      $mktrec{$msg_msn}[24] = $1;
    }
    if (m/\|NCH(\w+)\|/) {
      $mktrec{$msg_msn}[25] = $1;
    }
    if (m/\|NNT(\w+)\|/) {
      $mktrec{$msg_msn}[26] = $1;
    }
    if (m/\|NPR(\w+)\|/) {
      $mktrec{$msg_msn}[27] = $1;
    }
    if (m/\|NRM(\w+)\|/) {
      $mktrec{$msg_msn}[28] = $1;
    }
    if (m/\|GDP(\w+)\|/) {
      $mktrec{$msg_msn}[29] = $1;
    }
    if (m/\|PID(\w+)\|/) {
      $mktrec{$msg_msn}[30] = $1;
    }
    if (m/\|PNM(\w+)\|/) {
      $mktrec{$msg_msn}[31] = $1;
    }
    if (m/\|RRP(\w+)\|/) {
      $mktrec{$msg_msn}[32] = $1;
    }
    if (m/\|RMR(\w+)\|/) {
      $mktrec{$msg_msn}[33] = $1;
    }
    if (m/\|CUR(\w+)\|/) {
      $mktrec{$msg_msn}[34] = $1;
    }
    if (m/\|RQR(\w+)\|/) {
      $mktrec{$msg_msn}[35] = $1;
    }
    if (m/\|TRI(\w+)\|/) {
      $mktrec{$msg_msn}[36] = $1;
    }
    if (m/\|TNM(\w+)\|/) {
      $mktrec{$msg_msn}[37] = $1;
    }
    if (m/\|TAP([\w.-]+)\|/) {
      $mktrec{$msg_msn}[38] = $1;
    }
    if (m/\|PHN([\w.-]+)\|/) {
      $mktrec{$msg_msn}[39] = $1;
    }
    if (m/\|T1A(\w)/) {
      $mktrec{$msg_msn}[40] = $1;
    }
    if (m/\|AD1([\s\w\d.-\\]+)/) {
      $mktrec{$msg_msn}[41] = $1;
    }
    if (m/\|T2A(\w)\|/) {
      $mktrec{$msg_msn}[42] = $1;
    }
    if (m/\|AD2([\s\w\d.-@\\]+)/) {
      $mktrec{$msg_msn}[43] = $1;
    }
    if (m/\|CTY(\w+)\|/) {
      $mktrec{$msg_msn}[44] = $1;
    }
    if (m/\|RTY(\w+)\|/) {
      $mktrec{$msg_msn}[45] = $1;
    }
    if (m/\|CNF(\w+)\|/) {
      $mktrec{$msg_msn}[46] = $1;
    }
    if (m/\|CAN(\w+)\|/) {
      $mktrec{$msg_msn}[47] = $1;
    }
    if (m/\|BKR(\w+)\|/) {
      $mktrec{$msg_msn}[48] = $1;
    }
    if (m/\|SIN([\s\w\d.-]*)/) {
      $mktrec{$msg_msn}[49] = $1;
    }
    if (m/\|RFQ(\w+)\|/) {
      $mktrec{$msg_msn}[50] = $1;
    }
    if (m/\|RPD([\s\w\d.-]*)/) {
      $mktrec{$msg_msn}[51] = $1;
    }
    if (m/\|RPC(\w+)\|/) {
      $mktrec{$msg_msn}[52] = $1;
    }
    if (m/\|RTC(\w+)\|/) {
      $mktrec{$msg_msn}[53] = $1;
    }
    if (m/\|SEG(\w+)\|/) {
      $mktrec{$msg_msn}[54] = $1;
    }
    if (m/\|TIM(\w+)\|/) {
      $msgtime = `/qa/uswbin/tstamp -h $1 -o d`;
      chomp $msgtime;
      $mktrec{$msg_msn}[55] = $msgtime;
      $mktrec{$msg_msn}[56] = $msgtime;
      $mktrec{$msg_msn}[57] = ($msgtime + 1);
      $mktrec{$msg_msn}[58] = ($msgtime + 1);
      $mktrec{$msg_msn}[59] = ($msgtime + 2);
    }
  }
}
      
foreach $msn (keys %mktrec) {
  for($i = 0; $i < 60; $i++) {
    if ($i == 4 && !($mktrec{$msn}[$i])) {
      $mktrec{$msn}[$i] = 'u';
    }
    elsif ($i == 10 && !($mktrec{$msn}[$i])) {
      $mktrec{$msn}[$i] = "unk";
    }
    elsif ($i == 11 && !($mktrec{$msn}[$i])) {
      $mktrec{$msn}[$i] = "unk";
    }
    elsif ($i == 50 && !($mktrec{$msn}[$i])) {
      $mktrec{$msn}[$i] = 'D';
    }
    elsif ($i == 54 && !($mktrec{$msn}[$i])) {
      $mktrec{$msn}[$i] = 1;
    }
    print "$mktrec{$msn}[$i]|";
  }
  print "\n";
}

close INFILE;
