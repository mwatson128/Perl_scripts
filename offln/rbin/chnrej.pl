#!/bin/perl
#*TITLE - chnrej.pl - Perl script to run daily offline processes - 
#*SUBTTL Preface, and environment 
#
#
#	Copyright (C) 2011 THISCO, Inc.
#	      All Rights Reserved
#
#

$zone = `uname -n`;
chomp $zone;

require "/${zone}/usw/offln/rbin/logutils.pm";

$chnlogfile = "/${zone}/usw/offln/daily/chainrej.log";

# open chnlog files
open(LOGFILE, ">>$chnlogfile") || print STDERR "couldn't open logfile: $chnlogfile";

$ENV{TZ} = "UTC";
$dtime = `date`;

$GYD = "/uswsup01/usw/offln/bin/getydate";

# set program to flush the buffer
select((select(LOGFILE), $| = 1)[0]);

print LOGFILE "\n";
print LOGFILE "&" x 79;
printf LOGFILE "\n Started CHNREJ at $dtime \n";

# Set dbug if you want additional info...
$DBUG = 0;

# parameters set from environment variables
$lgrej_dir = "/${zone}/loghist/rej_all";
$rundir = "/${zone}/usw/offln/daily";
$ENV{TZ} = "UTC";
$tmpsum = 2;
$tmpvol = 3;
$tmperr = 4;

# get number of command-line arguments
if ($argc = @ARGV) {

  # test the first argument to see if it's a date
  $temp = shift(@ARGV);
  $argc--;
  if ( $temp =~ m{\d\d/\d\d/\d\d} ) {

    #it's a date. use it.
    $date = $temp;
  }
  else {
    $date = `$GYD -s`;
  }
}
else {
  $date = `$GYD -s`;
}

chomp($date);

# date strings for input/output files
$cdate = `$GYD -t ${date} -d 0`;
$t_cdate = `$GYD -t ${date} -d 1`;

# date string for billing file
$ndate = `$GYD -t ${date} -d 0 -o sig`;

# INPUT FILES
$lgrej_file = "rej${cdate}.lg";

# OUTPUT FILES
$CHNDIR = "${rundir}/chainrej";
$ulgout = "${CHNDIR}/tmp.ulgout";
$ulginject = "${CHNDIR}/tmp.ulginject";
$ulginject_new = "${CHNDIR}/tmp.ulginject.new";

if (! -d "$CHNDIR") {
  qx(mkdir $CHNDIR);
}

#create a list of enitites
%list = ();

$CPDIR = "/$zone/usw/reports/daily/chainrej";
$FTPSRV = "centralftp";
$IHGDIR = "/ads/ftp/bass/outgoing";
#$mailaddr = "pedpg\@pegs.com";
$mailaddr = "mike.watson\@pegs.com";

# Set up file location hash

$DBUG && print LOGFILE "\n :DJUNK: CHNREJ\n-----\n";
$DBUG && print LOGFILE " :DJUNK: INPUT FILES\n";
$DBUG && print LOGFILE " :DJUNK: lgrej_file: $lgrej_file\n";
$DBUG && print LOGFILE " :DJUNK: YESTERDAY'S OLD FILES\n";

chnrej();

$dtime = `date`;
printf LOGFILE "\n Ended CHNREJ at $dtime \n";
print LOGFILE "&" x 79;
print LOGFILE "\n";


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
  chdir $CHNDIR;
  foreach $entity ( keys %list ) {
    system("rm -f $entity.lgsplt 2>/dev/null");
    system("rm -f $entity.${cdate} 2>/dev/null");
  }
  system("rm -f $ulginject");
  system("rm -f $ulginject_new");
  system("rm -f $chnrej_no");
}

#*SUBTTL chnrej - run entire gammet of CHNREJ processing
#
# chnrej()
#
# run entire thread for processing of CHNREJ information
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val	- return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub chnrej 
{

  LOGENTER("CHNREJ");

  ($rtn_val = &chnrej_rcp);
  !($rtn_val = &chnrej_scan) || return($rtn_val);
  !($rtn_val = &chnrej_inject) || return($rtn_val);
  !($rtn_val = &chnrej_split) || return($rtn_val);
  !($rtn_val = &chnrej_mkent) || return($rtn_val);

  chdir ${rundir};

  LOGEXIT("CHNREJ");
}

#*SUBTTL chnrej_rcp - remote copies the REJ input files from loghist
#
# chnrej_rcp
#
# remote copies the CHNREJ input files from production
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val	- return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub chnrej_rcp 
{

  LOGENTER("CHNREJ_RCP");

  chdir ${rundir};

  print(LOGFILE "    REJ file is ${lgrej_file}\n");
  # get USW Rejectg Log
  #
  # check to see if reject log is compressed, or even there
  if (-e $lgrej_file) {
    print(LOGFILE "    REJ file ${lgrej_file} in rundir \n");
    # nothing to do
  }
  elsif (-f "${lgrej_dir}/${lgrej_file}" ||
         -f "${lgrej_dir}/${lgrej_file}.Z" ||
         -f "${lgrej_dir}/${lgrej_file}.gz") {

    # RCP the file
    print(LOGFILE "start RCP of ${lgrej_file}: ", `date`);
    $command = "cp ${lgrej_dir}/${lgrej_file}* . ";
    system ("$command >>$chnlogfile 2>>$chnlogfile");

    # uncompress the LGREJ file if needed
    print(LOGFILE "start UNCOMPRESS of ${lgrej_file}: ", `date`);
    $command = "gunzip ${lgrej_file}*.gz ";
    system("$command >> $chnlogfile 2>> $chnlogfile");

  }

  LOGEXIT("CHNREJ_RCP");
}

#*SUBTTL chnrej_scan - scan the reject logs and put them into text
#
# chnrej_scan
#
# Scan the reject logs and put them into a single text file.
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val	- return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub chnrej_scan 
{

  LOGENTER("CHNREJ_SCAN");

  print(LOGFILE "start SCAN of $lgrej_file  ", `date`);

  $ulgscan = "/$zone/usw/offln/bin/ulgscan";
  print(LOGFILE "start of ulgscan for ${cdate}: ", `date`);

  # Iterate through all rej files in this dir.
  @rej_files = qx(ls -1 rej${cdate}*);
  foreach $rej_file (@rej_files) {
    chomp $rej_file;
    next if ($rej_file =~ /.gz/);
    next if ($rej_file =~ /.Z/);
    print(LOGFILE "ulgscan for $rej_file : ", `date`);
    $command = "$ulgscan -c $rej_file find 'read -e' >> $ulgout";
    if ($rtn_val = system ("$command 2>>$chnlogfile")) {
      ($E_LOGX, $rtn_val);
      return($rtn_val);
    }
  }

  # Remove the + and ++ files to save space.  No one else uses them
  qx(rm -f rej${cdate}.lg+*);

  LOGEXIT("CHNREJ_SCAN");
  return($rtn_val);
} 

#*SUBTTL chnrej_inject - Read the file and break it up more.
#
# chnrej_inject
#
# Scans the text file, put in delimeters and reprint.
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val	- return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub chnrej_inject 
{

  LOGENTER("CHNREJ_INJECT");

  chdir $CHNDIR;
  print(LOGFILE "start INJECT at: ", `date`);

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
  system("rm -f $ulgout");

  print(LOGFILE "end INJECT at: ", `date`);
  LOGEXIT("CHNREJ_INJECT");
  return($rtn_val);
}

#*SUBTTL chnrej_split - Read the file and break it up more.
#
# chnrej_split
#
# Scans the text file, put in delimeters and reprint.
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val	- return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub chnrej_split 
{

  LOGENTER("CHNREJ_SPLIT");
  chdir $CHNDIR;
  print(LOGFILE "Start SPLIT in $CHNDIR at: \n\t", `date`);

  qx(/home/uswrpt/bin/chnrej_join tmp.ulginject > $ulginject_new);

  #remove old files
  unlink <*.lgsplt>;

  open(ULGINJECT2, "< $ulginject_new");
  while(<ULGINJECT2>) {
    
    # gather unique Entities
    if ($_ =~ /IP=(.*), entity/) {
      $whole_ent = $1;
      ($front, $back) = split /-/, $whole_ent;
      $front_len = length $front;
      $back_len = length $back;

      # for AALSRQ(2) and weed out '?' ent.
      if (0 == $back_len && 1 != $front_len ) {
        # Cut the numer off the end.
        if (7 == $front_len) {
	  $front =~ /([A-Z]*)[0-9]$/;
	  $short_ent = $1
	}
	# No number, just usw AALSRQ
	else {
          $short_ent = $whole_ent;
	}
      }
      # Normal 2 character chain
      elsif (2 == $front_len) {
        $short_ent = $front;
      }
      # Normal 3 character chain
      elsif (3 == $front_len) {
        ($l1, $l2, $l3) = split //, $front;
        if ($l3 =~ /[0-9]/) {
	  $short_ent = $l1 . $l2;
	}
	else {
	  $short_ent = $front;
	}
      }
      else {
        next;
      }
      
      #$chaincode_hash{$short_ent} = $whole_ent;
      $chaincode_hash{$whole_ent} = $short_ent;
    }
  }
  close(ULGINJECT2);
  system("rm -f $ulginject");

  foreach $ele (sort keys %chaincode_hash) {

    $shortName = $chaincode_hash{$ele};
    $list{$shortName} = $shortName;
    # create a file for each $shortName by greping through $ulginject_new
    $grep_key = "IP\=" . $ele . ", entity";
    $fName = $shortName . ".lgsplt";
    qx(grep "$grep_key" $ulginject_new >> $fName);

    # Now put a line break back in the message.
    qx(/bin/perl -p -i -e 's/N3WL1N3/\n/g' $fName);
  }
  print(LOGFILE "\n");

  print(LOGFILE "End SPLIT in $CHNDIR at: \n\t", `date`);
  LOGEXIT("CHNREJ_SPLIT");
  return($rtn_val);
}

#*SUBTTL chnrej_mkent - Split up the rejects by entity
#
# chnrej_mkent
#
# Make sure each entity has a file with rejects (or a filler) so an
# email will be sent.  Also, count the number of each type of reject
# the entity has, and provide one example
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val	- return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub chnrej_mkent 
{

  LOGENTER("CHNREJ_MKENT");
  chdir $CHNDIR;
  print(LOGFILE "Start MKENT in $CHNDIR at: \n\t", `date`);

  $/ = "\n";
  foreach ( keys %list ) {
    $ent_outfile = $_ . '.' . $cdate;
    if (!(-e "$_.lgsplt")) {
      system "echo filler > $_.lgsplt";
    }
    if (!(open(ENTITYLGSPLT, "$_.lgsplt"))) {
      barf "Could not open $_.lgsplt";
    }
    if (!(open(ENTITYHTML, ">${ent_outfile}"))) {
      barf "Could not open $ent_outfile";
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

  # CP the files to $CPDIR
  print(LOGFILE "In MKENT CP general files at: \n\t", `date`);
  system("rm -rf $CPDIR/* 2>/dev/null");
  foreach $entity ( keys %list ) {
    $ent_cpfile = $entity . '.' . $cdate;
    $errcode = system("cp $ent_cpfile $CPDIR");
    if ( (0xff00 & $errcode) > 0 ) {
      print "problem copying $entity\n";
    }
  }

  #########################
  ######### SCP all rejects for special HRSs
  ######### Right now just IHG so it's hard coded
  #########################
  print(LOGFILE "In MKENT SCP special files at: ", `date`);
  foreach $entity ( keys %list ) {
    if ($entity eq "HI") {
      if (!(-e "$entity.lgsplt") || -z "$entity.lgsplt") {
	qx(echo "No Rejects" > $entity.lgsplt);
      }
      qx(scp $entity.lgsplt $FTPSRV:$IHGDIR/IHG_REJ_${cdate}.txt);
    }
  }

  cleanup();

  print(LOGFILE "End MKENT in $CHNDIR at: ", `date`);
  LOGEXIT("CHNREJ_MKENT");
  return($rtn_val);
}

1;

