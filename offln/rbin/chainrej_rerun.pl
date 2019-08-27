#!/bin/perl
#*TITLE - chainrej.pl - Perl script to email rejected message count and example - 1.2
#*SUBTTL Preface, and environment
#
#  (]$[) chainrej.pl:1.2 | CDATE=13:50:55 09/20/01
#
#       Copyright (C) 2000 Pegasus Solutions
#             All Rights Reserved
#

$PID = getppid;
$| = 1;

#use integer;

################### 
###### Base directories
###################
$RUNDIR = "/support/vladimir/chainrej";
$LOGDIR = "/loghist/rej";
$COMPRESSEDLOGDIR = "/usw/reports/daily/dumper";
$RCPDIR = "/home/web/http/htdocs/prod/chainrej";
$RCPBOX = "sundev";
$RCPACT = "web";

$mailaddr = "mike.watson\@pegs.com";
#$mailaddr = "pedpg\@pegs.com";

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

#date is mmddyy
$date = sprintf("%02d%02d%02d", $mon + 1, $mday, $year);
$printdate = sprintf("%02d/%02d/%02d", $mon + 1, $mday, $year);
$monyear = sprintf("%02d%02d", $mon + 1, $year);

#create a list of enitites
%list = ();

# make sure reject file is there (or copy and uncompress the compressed file)
$FILENAME="${LOGDIR}/rej$date.lg";
if(!(open(FILE, $FILENAME))) {
  system("cp ${COMPRESSEDLOGDIR}/rej$date.lg.Z ${RUNDIR}");
  system("uncompress ${RUNDIR}/rej$date.lg.Z");
  $FILENAME="${RUNDIR}/rej$date.lg";
  if(!(open(FILE, $FILENAME))) {
    barf "Could not open Reject log $FILENAME";
  }
}
  
#########################
#########  Run ulgscan to get the reject messages for the desired entities
#########    put output into temporary file
#########################
system "/usw/runtime/bin/ulgscan -c $FILENAME find scan > $ulgout";


#########################
######### Read the ulgscan output (from $ulgout temporary file),  add new
#########   record separator, and put into another temporary file
#########################

# Open the ulgscan output file
if (!(open(ULGOUT, "$ulgout"))) {
  barf "Could not open $ulgout";
}
# Create temporary file
if (!(open(ULGINJECT, ">$ulginject"))) {
  barf "Could not open $ulginject";
}

while(<ULGOUT>) {
  if(m#^[0-2][0-9]/[0-3][0-9]/[0-9][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9]: [we]#
) {
    print ULGINJECT "-------\n";
  }
  print ULGINJECT;
}

close(ULGINJECT);
close(ULGOUT);

#########################
######### Read ulgscan output with new record separator (from $ulginject
#########  temporary file) and separate each entities rejects into its own 
#########  temporary *.lgsplt file
#########################
# Open temporary file
if (!(open(ULGINJECT2, "$ulginject"))) {
  barf "Could not open $ulginject";
}

$/ = "-------\n";
$| = 1;
$f = 3;
$chaincode = "";

#remove old files
unlink <*.lgsplt>;
while(<ULGINJECT2>) {
  $chaincode = "";
  SWITCH: {
    if(/IP=([A-Z][A-Z])[0-9]-B2, entity/) {
      $chaincode = $1;
      last SWITCH;
    } 
    if(/IP=([A-Z][A-Z])[0-9]-A2, entity/) {
      $chaincode = $1;
      last SWITCH;
    } 
    if(/IP=(.*)-B2, entity/) {
      $chaincode = $1;
      last SWITCH;
    } 
    if(/IP=(.*)-A2, entity/) {
      $chaincode = $1;
      last SWITCH;
    } 
    if(/IP=([A-Z][A-Z][A-Z]*)[0-9], entity/) {
      $chaincode = $1;
      last SWITCH;
    } 
    # Funky special case (bad)
    if(/IP=\?, entity/) {
      $chaincode = "BAD";
      last SWITCH;
    } 
    if(/IP=(.*), entity/) {
      $chaincode = $1;
      last SWITCH;
    } 
    $chaincode = "UNKN";

  }#end of switch

  if ("UNKN" ne $chaincode && "" ne $chaincode) {
    $list{$chaincode} = $chaincode;
    if (!(-e "$chaincode.lgsplt")) {
      open (OUTFILE, ">$chaincode.lgsplt") || barf "Could not open $chaincode.lgsplt";
      print OUTFILE $_ || barf "Could not print to $chaincode.lgsplt";
      close(OUTFILE) || barf "Could not close to $chaincode.lgsplt";
    }
    else {
      open (OUTFILE, ">>$chaincode.lgsplt") || barf "Could not open $chaincode.lgsplt";
      print OUTFILE $_ || barf "Could not print to $chaincode.lgsplt";
      close(OUTFILE) || barf "Could not close to $chaincode.lgsplt";
    }
  }
}
close(ULGINJECT2);

#########################
######### Make sure each entity has a file with rejects (or a filler) so an
#########   email will be sent.  Also, count the number of each type of reject
#########   the entity has, and provide one example
#########################
$/ = "\n";
foreach ( keys %list ) {
  if (!(-e "$_.lgsplt")) {
    system "echo filler > $_.lgsplt";
  }
  if (!(open(ENTITYLGSPLT, "$_.lgsplt"))) {
    barf "Could not open $_.lgsplt";
  }
  if (!(open(ENTITYHTML, ">$_.$date"))) {
    barf "Could not open $_.$date";
  }
  
  @errlist = ();
  @msg = ();
  $loop = TRUE;
  $printon = 0;
  $getsample = 0;
  bigloop: while(<ENTITYLGSPLT>){
    if(m/ternal format\)\n/) {
  
      $loop = FALSE;
      # push message onto list if applicable
      if ($getsample) {
        push (@errlist, ("1\n" . $ERR . $L1 . $L2 . (join ("",  @msg))));
        # Empty @msg
        while($tmpmsg = pop(@msg)) {
        }
      }
      $L1 = $_;
      $L2 = <ENTITYLGSPLT>;
      $ERR = <ENTITYLGSPLT>;
      foreach $e (@errlist) {
        ($qty, $err, $l1, $l2, @msg2) = split (/\n/, $e);
        if (($err . "\n") eq $ERR) {
  
          #already in list, bump quantity
          $qty++;
          $e = join ("\n", ($qty, $err, $l1, $l2, @msg2));
  
          $getsample = 0;
          next bigloop;
        }
      }
  
      $getsample = 1;
    }
    elsif ($getsample) {
      push (@msg, $_);
    }
  }
  if ($getsample) {
    push (@errlist, ("1\n" . $ERR . $L1 . $L2 . (join ("", @msg))));
  }

  #print the error list
  foreach $e (@errlist) {
    ($qty, $err, $l1, $l2, @msg) = split(/\n/, $e);

    # HTML
    print ENTITYHTML "REASON:\n";
    print ENTITYHTML $err . "\n";
    print ENTITYHTML "QUANTITY: ", $qty;
    print ENTITYHTML "\n";
    print ENTITYHTML "Sample:\n";
    print ENTITYHTML $l1 . "\n" . $l2 . "\n";
    foreach $l (@msg) {
      print ENTITYHTML $l . "\n";
    }
    print ENTITYHTML "\n";
  }

  if ($loop=~TRUE) {
    print ENTITYHTML "There were no rejects"
  }
  close(ENTITYLGSPLT);
  close(ENTITYHTML);
}

#########################
######### RCP the files to sundev
#########################
foreach $entity ( keys %list ) {
  system("rsh -l $RCPACT $RCPBOX mkdir $RCPDIR/$monyear 2>/dev/null");
  system("rsh -l $RCPACT $RCPBOX mkdir $RCPDIR/$monyear/$entity 2>/dev/null");
  $errcode = system("rcp $entity.$date $RCPACT\@$RCPBOX:$RCPDIR/$monyear/$entity/$entity.$date");
  if ( (0xff00 & $errcode) > 0 ) {
    print "problem copying $entity\n";
  }
}

cleanup;
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
  foreach $entity ( keys %list ) {
    system("rm $entity.lgsplt 2>/dev/null");
    system("rm $entity.$date 2>/dev/null");
  }
  system("rm $ulgout");
  system("rm $ulginject");
}
