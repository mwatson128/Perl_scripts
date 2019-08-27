#!/usr/local/bin/perl
# (]$[) trp_tcp_cnt.pl:%I% | CDATE=07/14/09 11:05:07
# CVS usw/offln/rbin
######################################################################
# This script goes through the runtime log and pulls out the 
# TRP TCP errors indicating window size problems.
######################################################################

#######################################
#  General config and variable setup  #
#######################################
$distro='Ted.Lankford@Pegs.com';
# Turn off/on Debugging
$DBUG = 1;
$DBUG = 0;

@machlist = qw (USWPROD01 USWPROD02 USWPROD03 USWPROD04 USWPRODCE01 USWPRODCE02 USWPRODCE03 USWPRODCE04 USWPRODCE05 USWPRODCE06 USWPRODCE07 USWPRODCE08 USWPRODCE09 USWPRODCE10 USWPRODCE11 USWPRODCE13 USWPRODCE14 USWPRODCE15) ;
@shortmachlist = qw ( prd1 prd2 prd3 prd4 ce01 ce02 ce03 ce04 ce05 ce06 ce07 ce08 ce09 ce10 ce11 ce13 ce14 ce15);

# TEDL: The only way I can think of to create a vertical short list :(
$vertshortmachlist{$machlist[0]}=$shortmachlist[0];
$vertshortmachlist{$machlist[1]}=$shortmachlist[1];
$vertshortmachlist{$machlist[2]}=$shortmachlist[2];
$vertshortmachlist{$machlist[3]}=$shortmachlist[3];
$vertshortmachlist{$machlist[4]}=$shortmachlist[4];
$vertshortmachlist{$machlist[5]}=$shortmachlist[5];
$vertshortmachlist{$machlist[6]}=$shortmachlist[6];
$vertshortmachlist{$machlist[7]}=$shortmachlist[7];
$vertshortmachlist{$machlist[8]}=$shortmachlist[8];
$vertshortmachlist{$machlist[9]}=$shortmachlist[9];
$vertshortmachlist{$machlist[10]}=$shortmachlist[10];
$vertshortmachlist{$machlist[11]}=$shortmachlist[11];
$vertshortmachlist{$machlist[12]}=$shortmachlist[12];
$vertshortmachlist{$machlist[13]}=$shortmachlist[13];
$vertshortmachlist{$machlist[14]}=$shortmachlist[14];
$vertshortmachlist{$machlist[15]}=$shortmachlist[15];
$vertshortmachlist{$machlist[16]}=$shortmachlist[16];
$vertshortmachlist{$machlist[17]}=$shortmachlist[17];
$vertshortmachlist{$machlist[18]}=$shortmachlist[18];
$vertshortmachlist{$machlist[19]}=$shortmachlist[19];

$zone = `uname -n`;
chomp $zone;

###################################################
#  Set the date and locate the rtlog in loghist  #
###################################################
if ($#ARGV < 0) {
  $date=`/$zone/usw/offln/bin/getydate -s`;
} else {
  if ($ARGV[0] =~ /^\d\d\/\d\d\/\d\d$/) {
    $date = $ARGV[0];
  } else {
    die "Invalid date formate: mm/dd/yy\n";
  }
}
($month, $day, $year) = split(/\//, $date);
$rtday = $day + 0;
$DBUG && print("Date: $month/$day/$year\n");

$rtlog_dir = "/uswsup01/loghist/trptcp/rtlogs/";
$tcp_dir = "/$zone/usw/reports/daily/trptcp/";
if (! -d "$tcp_dir/$month$year") {
  qx(mkdir $tcp_dir/$month$year);
}


$rtlogfile  = $rtlog_dir . $month . $year . "/rtlog" . $rtday;
$trptcpfile = $tcp_dir . $month . $year . "/trptcp." . $month . $day . $year;

$tcplogfile = $tcp_dir . "trptcp.log";

#######################################################################
# For now get the rtlog from uswsd01 
#######################################################################
if (! -d "$rtlog_dir/$month$year") {
  qx(mkdir $rtlog_dir/$month$year);
}

if (! -f $rtlogfile) {
  qx(scp usw\@uswsd01:/uswsd01/logs/rtlogs/rtlog$rtday $rtlogfile-);
  qx(grep TCPITSW $rtlogfile- > $rtlogfile);
  qx(rm -f $rtlogfile-);
}

# Close STDOUT and open it as the tcplog file.  Comment out these two
# lines if you want to run this to the display.
close STDOUT;
open STDOUT, ">> $tcplogfile" or die "Can't open tcplog file $tcplogfile\n";

#######################################################################
#  Open the rtlog file and start parsing the data.  Build the hash
#  while the data is parsed.  This seems to save a lot of mem usage,
#  although overall execution time increases.
#######################################################################
$DBUG && print("Open RTLOG ($rtlogfile)\n");
open RTLOG, $rtlogfile or 
  open RTLOG, "gunzip -c $rtlogfile |" or
  die "Can't open rtlog file $rtlogfile\n";
while ($block = <RTLOG>) {
$DBUG && print("BLOCK:'$block'\n");

  # Grab only TRP TCP warning lines
  if ($block =~ /TCPITSW/) {
  
    $DBUG && print("Found TCPITSW\n");

    # This is here because once in a while multiple rtlog entries will
    # somehow make it to the same logical line, so split on the "["
    # that encapsulates a machine name.  
    @block = split(/\[/, $block);

    # Treat each piece of the line as a separate line
    for $line (@block) {
$DBUG && print("TCP LINE:'$line'\n");

      # Double check to see if its still a TCP warning
      if ($line =~ /TCPITSW1/) {

        # Pull the DATE/TIME, HOST, IP/TRP, DEST, count out of the line
#[USWPRODCE04] <= 07/13/10 15:14:01 (HI2-A2) EX(TCPITSW2): Warning: TCP send buffered for "138.113.131.111:H4-TRP3A" (1 in last 4812 seconds) =>
        $DBUG && print("TCP LINE1:'$line'\n");
        $line =~ /^(.+)\] <= (.+) (.+) \((.+)\) .* "(.+):(.+)" /;
#        $line =~ /^(.+)\] <= (\d\d/\d\d/\d\d) (\d\d:\d\d:\d\d) \((.+)\) .* "(.+):(.+)" /;
#        $line =~ /^(.+)\] .* \((.+)\) .* "(.+):(.+)" /;
        $src = $1;
	$date = $2;
	$time = $3;
	$srcapp = $4;
	$dst = $5;
	$dstapp = $6;
	$cnt = 1;
      }
      elsif ($line =~ /TCPITSW2/) {

        # Pull the HOST, IP/TRP, DEST, count out of the line
#[USWPRODCE04] <= 07/13/10 15:14:01 (HI2-A2) EX(TCPITSW2): Warning: TCP send buffered for "138.113.131.111:H4-TRP3A" (1 in last 4812 seconds) =>
        $DBUG && print("TCP LINE2:'$line'\n");
        $line =~ /^(.+)\] <= (.+) (.+) \((.+)\) .* "(.+):(.+)" \((.+) in last/;
        $src = $1;
	$date = $2;
	$time = $3;
	$srcapp = $4;
	$dst = $5;
	$dstapp = $6;
	$cnt = $7
      }
      else {
        $src = "";
	$date = "";
	$time = "";
	$srcapp = "";
	$dst = "";
	$dstapp = "";
	$cnt = "";
      }

      $DBUG && print("Data: '$src' '$srcapp' '$dst' '$dstapp' '$cnt'\n");

      # Make sure we have src/dst 
      if ($src && $dst) {

        # dst is an IP address, convert to name
        if ($dst) {
          $DBUG && print("dst($dst)\n");
          @nslookup = qx(/usr/sbin/nslookup $dst);
#$DBUG && print("nslookup[0]: '$nslookup[0]'\n");
#$DBUG && print("nslookup[1]: '$nslookup[1]'\n");
#$DBUG && print("nslookup[2]: '$nslookup[2]'\n");
          chomp $nslookup[3];
          $DBUG && print("nslookup[3]: '$nslookup[3]'\n");
          $nslookup[3] =~ /.* (.+).pegs.com./;
          $dstname = $1;
          $DBUG && print("dstname($dstname)\n");
          $DSTNAME = uc($dstname);
          $DBUG && print("DSTNAME($DSTNAME)\n");
        }
$DBUG && print("DATA: '$src' '$srcapp' '$DSTNAME' '$dstapp' '$cnt'\n");

        # Add to the source count 
        $srctcp{$src} += $cnt;
        $DBUG && print("SRC($src) TCP CNT $srctcp{$src}\n");

        # Add to the dest count 
        $dsttcp{$DSTNAME} += $cnt;
        $DBUG && print("DST($DSTNAME) TCP CNT $dsttcp{$DSTNAME}\n");

        # Add to the src/dest count 
        $srcdsttcp{$src}{$DSTNAME} += $cnt;
        $DBUG && print("SRCDST($src,$DSTNAME) TCP CNT $srcdsttcp{$src}{$DSTNAME}\n");
      }
    }
  }
}
$DBUG && print("Close RTLOG\n");
close RTLOG;

############################
# Send an email w/ the log #
############################

close STDOUT;
open STDOUT, "> $trptcpfile" or die "Can't open $trptcpfile\n";

# Build the header and border
$header = sprintf "|%2.2d%2.2d%2.2d", $month, $day, $year;
$border = "|------";
for $mach (@shortmachlist) {
  $header .= sprintf "|%4s", $mach;
  $border .= "+----";
}
$header .= "| dst|";
$border .= "+----|";

# Write the header and border
printf $border . "\n";
printf $header . "\n";
printf $border . "\n";

for $srcmach (@machlist) {
  printf "|%5s ", $vertshortmachlist{$srcmach};
  $DBUG && print("\nvertshortmachlist[$srcmach] '$vertshortmachlist{$srcmach}'\n");
  for $dstmach (@machlist) {
    printf "|%4d", $srcdsttcp{$srcmach}{$dstmach};
#    $DBUG && print("\nsrcdsttcp[$srcmach][$dstmach] '$srcdsttcp{$srcmach}{$dstmach}'\n");
  }
  printf "|%4d|\n", $srctcp{$srcmach};
}
printf $border . "\n";

printf "| src  |";
for $dstmach (@machlist) {
  printf "%4d|", $dsttcp{$dstmach};
  $dstmachttl += $dsttcp{$dstmach};
}
printf "%4d|\n", $dstmachttl;
printf $border . "\n";

`/bin/mailx -s "$date TRP TCP Warning Summary" $distro < $trptcpfile`;
