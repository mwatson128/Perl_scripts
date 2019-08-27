#!/bin/perl
# (]$[) daily_cust_rep.pl:1.26 | CDATE=08/19/08 14:02:19
######################################################################
# daily_cust_rep.pl will perform a downtime and reject log analysis report for a 
# particular chain.  More specifically, it keys off the primary 
# chain ID assigned to a customer.  The downtime is pulled from the
# awklog report that is generated by cron on usw_prod, and the reject
# log analysis is pulled from the daily dumper.
######################################################################
# Usage: daily_cust_rep.pl <chain> <options>
#   <chain>   :  Valid primary chain code, not a sub-chain.
#   <options> :  At this point options are a space delimited list of
#                what reports you want to run. 
#                dt: Downtime Report
#                rj: Reject Log Analysis
#                to: Timeout Report
######################################################################
$zone = `uname -n`;
chomp $zone;

######################################################################
# Dumps the usage statement and exits with non-zero error code.
######################################################################
sub usage {
  if ($_[0]) {
    $errorcode=$_[0];
  } else {
    $errorcode=255;
  } 
  print "usage: $0 <options> <chain> <reports>\n";
  print " options : CFG=<config file> or DATE=<mm/dd/yy>\n";
  print " chain   : HRS=<Must be a valid primary chain>\n";
  print " reports : \"dt\", \"to\", or \"rj\"\n";
  exit $errorcode;
}

######################################################################
# Does just that.  Parses the command line and creates variables based
# on those values.
######################################################################
sub parse_command_line {
  $cfg_flag = "";
  $date_flag = "";
  $hrs_flag = ""; 
  $dt_flag = "";
  $rj_flag = "";
  $to_flag = "";
  if ($#ARGV > 0) {
    @args=@ARGV;
    for $arg (@args) {
      if ($arg =~ /\=/) {
        ($vartype, $value) = split /\=/, $arg;
        if ($vartype eq "CFG") {
          $configfile = $value;
          $cfg_flag = "YES";
        } elsif ($vartype eq "DATE") {
          if ($value =~ /\d\d\/\d\d\/\d\d/) {
            $date = $value;
            $date_flag = "YES";
          }
        } elsif ($vartype eq "HRS") {
          $chain = $value;
          $hrs_flag = "YES";
        } else {
          usage 2;
        }
    } else {
      if ($arg eq "dt") {
        if ($dt_flag eq "YES") {
          print STDERR "Duplicate argument \"dt\"\n";
        } else {
          $dt_flag = "YES";
        }
      } elsif ($arg eq "rj") {
        if ($rj_flag eq "YES") {
          print STDERR "Duplicate argument \"rj\"\n";
        } else {
          $rj_flag = "YES";
        }
      } elsif ($arg eq "to") {
        if ($to_flag eq "YES") {
          print STDERR "Duplicate argument \"to\"\n";
        } else {
          $to_flag = "YES";
       }
      } else {
        print STDERR "Unknown option: " . $item . "\n";
        usage 2;
      } 
    }
  } 
  }
}

######################################################################
# Does the system cleanup on a good exit.  I thought there was going
# to more to do, but so far there hasn't been.
######################################################################
sub cleanup {
  system "mv -fi $mail{message} $archive_dir";
}

######################################################################
# This loads in the config file.  It will ignore blank lines, as well
# as lines beginning with a # character.  It basically tries to match
# the chain code with the first two letters of each line to find a 
# match, and uses that line as the config.  This is a | (pipe) 
# delimited file.
######################################################################
sub absorb_config {
  $InConfig="NO";
  open CONFIG, "$_[0]" or die "Can\'t open $_[0]\n";
  while ($line=<CONFIG>) {
    if ($line !~ /^#|^$/) {
      chomp $line;
      @line = split /\|/, $line; 
      if ($line[0] eq $chain) {
        $mail{message}="/tmp/mailmessage.$$";
        $InConfig="YES";
        shift @line;
        $CustName=shift @line;
        $mail{recipients}="";
        foreach $address (@line) {
          $mail{recipients}=$mail{recipients} . " " . $address;
        }
        if ($date_flag ne "YES") {
          $date=`/$zone/usw/offln/bin/getydate -s`;
        }
        chomp $date;
        ($month, $day, $year)=split /\//, $date;
        $mail{subject}=$CustName . " Daily ";
        if ($dt_flag eq "YES") {
          if ($rj_flag eq "YES" ) {
            $mail{subject}=$mail{subject} . "Downtime and Reject Log Analysis ";
          } else {
            $mail{subject}=$mail{subject} . "Downtime ";
          }
        } else {
          $mail{subject}=$mail{subject} . "Reject Log Analysis ";
        }
        $mail{subject}=$mail{subject} . "for " . $date;
      }
    }
  }
  close CONFIG;
}

######################################################################
# This creates other variables not based on the config file.  
######################################################################
sub general_configs {
  $monthdir = $month . $year;
  $filedate = $month . $day . $year;
  $awklogfile="/$zone/loghist/uswprod01/awklogs/" . $monthdir . "/awklog20" .
    $year . $month . $day;
  $dumperfile="/$zone/usw/reports/daily/dumper/" . $filedate . ".dump";
  $chainrej = "/$zone/usw/reports/daily/chainrej/" . $chain . "." . $filedate;
  $daywoz = $day + 0;
  $tologfile = "/$zone/usw/reports/daily/tologs/" . $monthdir . "/tolog" . $daywoz;
  $dblogfile = "/$zone/usw/reports/daily/dstblogs/" . $monthdir . "/dblog" . $daywoz;
  $archive_dir="/$zone/usw/reports/daily/downtime/" . lc $chain . "/" . lc $chain .
               "20" . $year . $month . $day;
  
  # Check for a symaphore that means chainrej didn't finish.
  $chnrej_no = "/$zone/unload/chainrej/chainrej_$filedate.NOTOK";
}

######################################################################
# Main execution of script.  
######################################################################
parse_command_line;
if ($cfg_flag ne "YES") {
  $configfile = "/$zone/usw/offln/bin/daily_cust_rep.cfg";
}
absorb_config $configfile;
general_configs;

# Closing STDOUT and opening for writing, so all STDOUT will be mailed.
close STDOUT;
open STDOUT, "> $mail{message}" or die "Cannot open $mail{message} for writing\n";

#####################################################################
# If the dt option was given, lets pull the downtime for this chain.
#####################################################################
if ($dt_flag eq "YES") {
  open AWKLOG, "$awklogfile" or die "Cannot open $awklogfile \n";
  $headerflag=0;
  while ($line=<AWKLOG>) {
    if ($line =~ / $chain/ && $line !~ /MON/) {
      chomp $line;
      @line=split /  */, $line;
      if ($headerflag == 0) {
        $date=$line[0];
        print $CustName . " daily downtime report for " . $date . "\.\n\n";
        printf "%10s  %10s  %4s  %6s\n", "Time Down", "Time Up", "Minutes", "PID";
        $headerflag=2;
      }
      ($junk,$dt)=split /=/, $line[4];
      printf "%10s  %10s  %4s      %6s\n", $line[1], $line[2], $dt, $line[3];
    }
  }
  close AWKLOG;
  print "\n\n";
}

######################################################################
# The to option was given, lets give them the daily timeout analysis.
######################################################################
if ($to_flag eq "YES") {
  open TOLOG, $tologfile or die "Can't open $tologfile\n";
  $write_flag = "OFF";
  while ($line = <TOLOG>) {
    if ($line =~ /^$chain/ || 
	($chain eq "GW" && $line =~ /^WB/) ||
	($chain eq "WS" && $line =~ /^1P/)) {
      @block = ();
      $title = $CustName . " Daily Timeout Report\n\n";
      push @block, $title;
      push @block, $line;
      $write_flag = "ON";
    } elsif ($line =~ /^Total/) {
      if ($write_flag eq "ON") {
        for $item (@block) {
          print $item;
        }
        print $line . "\n\n";
      }
      $write_flag = "OFF";
      @block = ();
    } elsif ($write_flag eq "ON") {
      push @block, $line;
    }
  }
  close TOLOG;

  # No DestBusy Reports for GDSs
  if ($chain ne "1A" && $chain ne "AA" && $chain ne "HD" && $chain ne "MS" &&
      $chain ne "GW" && $chain ne "WS" && $chain ne "UA") {

  open DBLOG, $dblogfile or die "Can't open $dblogfile\n";
  $write_flag = "OFF";

  while ($line = <DBLOG>) {
    if ($line =~ /^$chain/) {
        @block = ();
        $title = $CustName . " Daily Destination Busy Report\n\n";
        push @block, $title;
        push @block, $line;
        $write_flag = "ON";
      } elsif ($line =~ /^Total/) {
        if ($write_flag eq "ON") {
          for $item (@block) {
            print $item;
          }
          print $line . "\n\n";
        }
        $write_flag = "OFF";
        @block = ();
      } elsif ($write_flag eq "ON") {
        push @block, $line;
      }
    }
  }
  close DBLOG;
}

##############################################################################
# If the rj function was given, lets give them the reject log analysis stuff.
##############################################################################
if ($rj_flag eq "YES") {
  if (open CHAINREJ, "$chainrej") {
    $count=0;
    $flag=0; 
    $hold = "";
    while ($line=<CHAINREJ>) {
      chomp $line;

      # We need to reconnect the lines and rebreak at 68 characters.
      # If the line is blank, there's nothing else to do.
      if ($line =~ /^$/) {
        print $line;
        print "\r\n";
      }
      # If the line end in \ then get rid of the \ and store in hold
      elsif ($line =~ /\\$/) {
        chop $line;
        $hold .= $line;
      }
      # Normal line ending.
      else {
        $i = 0;
        # If hold has something stored in it, deal with it.
        if ($hold) {
          $hold .= $line;
          @ln_a = split //, $hold;
          # Count the characters and insert a newline after 68.
          foreach $ch (@ln_a) {
            if ($i == 68) {
              print "$ch\r\n";
              $i = 0;
            }
            else {
              print $ch;
              $i++;
            }
          }
          $hold = "";
        }
        # Otherwise, just count off 68 characters and print.
        else {
          if ($line eq "-------") {
            print "\r\n";
            next;
          }
          @ln_a = split //, $line;
          foreach $ch (@ln_a) {
            if ($i == 68) {
              print "$ch\r\n";
              $i = 0;
            }
            else {
              print "$ch";
              $i++;
            }
          }
          print "\r\n";
        }
      } 
    }
  }
  elsif (-f $chnrej_no) {
    # Chainrej failed, write a warning.
    print "#" x 68;
    print  "\r\n";
    print "# The Reject portion of this report had complications while\r\n";
    print "# running, please be patient and the report will be rerun soon.\r\n";
    print "#" x 68;
    print  "\r\n";
  }
  else {
    # Chainrej worked, but this customer didn't have any rejects.
    print "#" x 68;
    print  "\r\n";
    print "# $chain had no rejects for $filedate\r\n";
    print "#" x 68;
    print "\r\n";
  }

  close CHAINREJ;
}

close STDOUT;

# Mail it to the people who want it.
system "mailx -r uswrpt\@pegs.com -s \"$mail{subject}\" \"$mail{recipients}\" < $mail{message}";

# Clean up after ourselves.
cleanup;
