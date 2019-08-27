#!/usr/local/bin/perl
# (]$[) gds_tcp_cnt.pl:1.6 | CDATE=07/14/09 11:05:07
######################################################################
# This script goes through the runtime log and pulls out the GDS
# TCP errors indicating window size problems.
# A daily report by GDS should suffice
######################################################################

#######################################
#  General config and variable setup  #
#######################################
$distro='Ted.Lankford@Pegs.com Chris.Munchrath@Pegs.com Christian.Bilke@Pegs.com Richard.Blair@Pegs.com';
$distro='Ted.Lankford@Pegs.com';
# Turn off/on Debugging
$DBUG = 1;
$DBUG = 0;
@gdslist = qw "AA UA WS 1A GW MS HD";  # List of all GDS's
$gdslist = join " ", @gdslist;  # Same list, but in a single var
$zone = `uname -n`;
chomp $zone;
$log_dir = "/$zone/loghist/uswprod01";
$tcp_dir = "/$zone/usw/reports/daily/gdstcp/";

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
$day = $day + 0;
$rtlogfile = "$log_dir/rtlogs/" . $month . $year . "/rtlog" . $day;
$tcplogfile = $tcp_dir . "gdstcp.log";

# Close STDOUT and open it as the tcplog file.  Comment out these two
# lines if you want to run this to the display.
close STDOUT;
open STDOUT, ">> $tcplogfile" or die "Can't open tcplog file $tcplogfile\n";

#######################################################################
#  Open the rtlog file and start parsing the data.  Build the hash
#  while the data is parsed.  This seems to save a lot of mem usage,
#  although overall execution time increases, it stil takes less
#  than 30 seconds to run a day.
#######################################################################
$DBUG && print("Open RTLOG ($rtlogfile)\n");
open RTLOG, $rtlogfile or 
  open RTLOG, "gunzip -c $rtlogfile |" or
  die "Can't open rtlog file $rtlogfile\n";
while ($block = <RTLOG>) {

  # Grab only tngate / mgate TCP warning lines
  if ($block =~ /TNGWTNG|MAGWMTS/) {
  
    $DBUG && print("Found TNGWTNG|MAGWMTS\n");

    # This is here because once in a while multiple rtlog entries will
    # somehow make it to the same logical line, so split on the "["
    # that encapsulates a machine name.  All CTTM lines come from a 
    # comm engine so all that will be there.
    @block = split(/\[/, $block);

    # Treat each piece of the line as a separate line
    for $line (@block) {

      # Double check to see if its still a TCP error
      if ($line =~ /TNGWTNG/) { 

        # Pull the GDS out of the line
        $DBUG && print("TN LINE:'$line'\n");
        $line =~ / \((..+)-TCPA-P\) EX\(TNGWTNG[12]\): Warning:/;
        $gds = $1;
      }
      elsif ($line =~ /MAGWMTS/) { 

        # Pull the GDS out of the line
        $DBUG && print("MG LINE:'$line'\n");
	$line =~ / \((..+)-TCPA-P\) EX\(MAGWMTS[12]\): Warning:/;
        $gds = $1;
      }
      else {
        $gds = "";
      }

      $DBUG && print("GDS '$gds'\n");

      # In the even that the GDS ID in the message is not the base
      for $gds_base (@gdslist) {
        if ($gds =~ /$gds_base/) {
          $gds = $gds_base;
          $DBUG && print("GDS base $gds\n");

          # In the future we might want to drill down on the TCP warning
          # message but for now we are just counting messages
          # 
          # [SUNTCP6] <= 09/15/08 02:21:54 (WS-TCPA-P) EX(MAGWMTS1): Warning: TCP send failed! =>
          # [SUNTCP6] <= 09/16/08 17:13:40 (WS-TCPA-P) EX(MAGWMTS2): Warning: TCP send failed (2 in last 139906 seconds) =>
          # [SUNTCP3] <= 09/15/08 02:35:06 (UA-TCPA-P) EX(TNGWTNG1): Warning: TCP send failed (1 in last 11121 seconds) =>

          $gdstcp{$gds} += 1;
          $DBUG && print("GDS($gds) TCP CNT $gdstcp{$gds}\n");
        }
      }
    }
  }
}
$DBUG && print("Close RTLOG\n");
close RTLOG;

########################
#  Print GDS breakdown #
########################
printf " %s", $date;
foreach $gds (@gdslist) {
  printf "%7s", ($gdstcp{$gds}) ? $gdstcp{$gds} : "0";
}
print "\n";

############################
# Send an email w/ the log #
############################

close STDOUT;
$mailfile = "/tmp/mailtemp." . $$;
open STDOUT, "> $mailfile" or die "Can't open $mailfile\n";
printf "   Date       AA     UA     WS     1A     WB     MS     HD\n";
for $line (`/bin/tail -32 $tcplogfile`) {
  print $line;
}

`/bin/mailx -s "Daily GDS TCP Warning Summary" $distro < $mailfile`;

`/bin/rm -f $mailfile`;
