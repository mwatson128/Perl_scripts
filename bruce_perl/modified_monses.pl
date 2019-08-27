#!/bin/perl
#
# Gather DB stats: 
# Store in human-readable log file.
#
# THIS SCRIPT REQUIRES PERL.
#
# (]$[) monses.pl:1.7 | CDATE=04/29/07 19:16:45
#
# 10/20/2009 - Modified by Fengming Lou for 1). Fixed sleep with negative time 2). Trap QUIT signal to exit
#              3). Removed hourly rotation of Monses process

use FileHandle;
use Getopt::Std;
use POSIX qw(strftime);

# Subs
sub usageexit;
# Get instance from command line
getopts('i');
$ARGC = @ARGV;
if ($ARGC == 1) {
  chomp($INSTANCE = $ARGV[0]);
}
else {
  usageexit();
}

## Set up the Environment Variables
$INFORMIXDIR="/informix-$INSTANCE";
$ENV{INFORMIXDIR}=$INFORMIXDIR;
$ENV{PATH}="$INFORMIXDIR/bin:/bin";
$INFORMIXSERVER="${INSTANCE}";
$ENV{INFORMIXSERVER}=$INFORMIXSERVER;
$ENV{TZ}="GMT0";

# Make sure INFORMIXDIR is valid
if (! -d "$INFORMIXDIR") {
  print "Invalid instance (INFORMIXDIR=$INFORMIXDIR)\n";
  usageexit();
}

# Make sure ROOTDIR is valid
&checkMonthRollover();

## Set up variables
$refresh = 30;
$staleReadyQ = 60;
$minWindowSize = 8192;
$winBucketSize = 2048;
$queueBucketSize = 512;
$INF_PORT = 1602;
$SIG{QUIT} = \&QUIT_handler;


# As of 2009-04-10, this is the standard location for all online logs.
# File naming conventions are not standard, so check both variations.
if (-f "/$zone/informix/logs/$INSTANCE.log") {
  $INF_LOG = "/$zone/informix/logs/$INSTANCE.log";
} elsif (-f "/$zone/informix/logs/online_$INSTANCE.log") {
  $INF_LOG = "/$zone/informix/logs/online_$INSTANCE.log";
} else {
  $INF_LOG = "NONE";
}

# Create output file names
$filedate = `date +%Y%m%d`;
chomp $filedate;

# Build filename to open
$outputFile = sprintf "%s/monses.%s", $ROOTDIR, $filedate;
$outputRawFile = sprintf "%s/monsesRaw.%s", $ROOTDIR, $filedate;
$outputStatsFile = sprintf "%s/monsesStats.%s", $ROOTDIR, $filedate;

# unbuffer STDOUT
STDOUT->autoflush(1);

if ($INF_LOG ne "NONE") {
  open(ONLINE_LOG, $INF_LOG) || die "Error opening Online Log\n";
  while (<ONLINE_LOG>) {
    next unless (/ Checkpoint Completed:  duration was (\d+) seconds/);
    $checkpointDur = $1;
    $chkptpos = tell(ONLINE_LOG);
  }
}
close(ONLINE_LOG);

# open up output file
open (OUT, ">> $outputFile");
open (RAW, ">> $outputRawFile");
OUT->autoflush(1);
RAW->autoflush(1);

########################################
# Loop through iterations              #
########################################
while (1 == 1){
  &checkHourRollover();

  my $sleeptime = 0; 
  $begin = time();

  print OUT '='x60,"\n";
  print OUT `date -u`;

  print RAW '='x60,"\n";
  print RAW `date -u`;

  $cmd_data = "[" . strftime("%Y-%m-%d %T", gmtime($begin)) . "][$zone][monses]";

  # get the data
  @onstat_ses=`onstat -g ses`;
  @onstat_rea=`onstat -g rea`;
  @onstat_act= `onstat -g act`;
  @onstat_bufs= `onstat -u`;
  @onstat_lock= `onstat -k`;
  @onstat_glo= `onstat -g glo`;
  @netstat = `netstat -an | grep ESTABLISHED | grep $INF_PORT`;
  $load = `uptime`;
  @vmstat= `vmstat 1 2`;

  # process each sub item
  &processReadyQueues();
  &processCheckPoint();
  &processSessions();
  &processBuffers();
  &processLocks();
  &processNetwork();
  &processVPs();
  &processLoad();
  &processVmstat();

  # Log the statistical output
  system("echo $cmd_data >> $outputStatsFile");

  $firstRun = 0;
  my $time_stamp = `date +"%Y-%m-%d %H:%M:%S"`;
  chomp $time_stamp;
  print RAW "$time_stamp - ",(time()-$begin)," sec(s) processing time\n";
  $sleeptime = $refresh - (time()-$begin);
  if ($sleeptime > 0) {
    sleep $sleeptime;
  } else {
    sleep 10;
  }
}

#close(OUT);
#close(RAW);
#exit(0);

###################################################################
# Check if new month and create new directory
sub checkMonthRollover{
    $zone = `/usr/bin/uname -n`;
    chomp $zone;
    $monthdir = `date +"/$zone/logs/perf/%m%y"`;
    chomp $monthdir;
    if ($ROOTDIR ne $monthdir) {
        $ROOTDIR = $monthdir;
        if (!-d "$ROOTDIR") {
            mkdir $ROOTDIR or do { print "Invalid ROOTDIR ($ROOTDIR) $!\n";
                                   &QUIT_handler("Directory Create Error"); }
        }
    }
}
###################################################################
sub checkHourRollover{
    &checkMonthRollover();
    $new_filedate = `date +%Y%m%d`;
    chomp $new_filedate;
    if ($new_filedate ne $filedate){
        if (defined OUT){
            print "Closing file $outputFile...\n";
            close(OUT);
        }
        if (defined RAW) {
            print "Closing file $outputRawFile...\n";
            close(RAW);
        }
        # Build filename to open
        $outputFile = sprintf "%s/monses.%s", $ROOTDIR, $new_filedate;
        $outputRawFile = sprintf "%s/monsesRaw.%s", $ROOTDIR, $new_filedate;
        $outputStatsFile = sprintf "%s/monsesStats.%s", $ROOTDIR, $new_filedate;
        # open up output file
        open (OUT, ">> $outputFile");
        open (RAW, ">> $outputRawFile");
        OUT->autoflush(1);
        RAW->autoflush(1);
        #update filedate
        $filedate = $new_filedate;
    }
}
###################################################################
sub QUIT_handler {
    my $signame = shift;
    my $time = `date +"%Y-%m-%d %H:%M:%S"`;
    print "\n=================\n ";
    print "Got signal $signame at $time ";
    if (defined OUT){
        print "Closing file $outputFile...\n";
        close(OUT);
    }
    if (defined RAW) {
        print "Closing file $outputRawFile...\n";
        close(RAW);
    }
    exit;
}
###################################################################
sub processVPs {

  $activeSQLThreads = scalar(grep(/\d+cpu\s+sqlexec/, @onstat_act));
  print OUT "Active sqlexec threads = $activeSQLThreads\n";
  $cmd_data .= sprintf("[activeSQLThreads=%d]", $activeSQLThreads);

  $activeKAIOThreads = scalar(grep(/\d+cpu\s+kaio/, @onstat_act));
  print OUT "Active kaio threads = $activeKAIOThreads\n";
  $cmd_data .= sprintf("[activeKAIOThreads=%d]", $activeKAIOThreads);


  # interpret Informix VP utilization
  %lastVPClassSum = %vpClassSum; %lastVPSum = %vpSum;
  %vpClassSum = {}; %vpSum = {};
  $sumCPU = 0.0;

  for ($i = 0; $i < $#onstat_glo; ++$i) {
    next unless ($onstat_glo[$i] =~ /(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/);
    ($vpID, $pid, $vpClass, $userCPU, $sysCPU, $totalCPU) = ($1, $2, $3, $4, $5, $6);
    next if ($vpClass eq "total");

    $vpSum{$vpID} = $totalCPU;
    $vpClass{$vpID} = $vpClass;
    $vpClassSum{$vpClass} += $totalCPU;
    $sumCPU += $totalCPU - $lastVPSum{$vpID};
  }
 
  return if ($firstRun);

  print OUT sprintf("Informix took %0.2fs of CPU\n", $sumCPU);
  return unless ($sumCPU > 0); 

  print RAW sprintf("Informix took %0.2fs of CPU\n", $sumCPU);
  $cmd_data .= sprintf("[secondsOnCPU=%0.2f]", $sumCPU);

  foreach $vpClass (sort { $vpClassSum{$b} - $lastVPClassSum{$b} <=> $vpClassSum{$a} - $lastVPClassSum{$a} } keys %vpClassSum) {
    $spent = $vpClassSum{$vpClass} - $lastVPClassSum{$vpClass};
    next unless ($spent > 0);
    print OUT sprintf("  %s VP Class spent %0.2fs on CPU (%0.1f%% of engine)\n",
      $vpClass, 
      $spent,
      $spent /  $sumCPU * 100);
    $cmd_data .= sprintf("[%s.percentEngine=%0.2f]", $vpClass, $spent /  $sumCPU * 100);
  }

  foreach $vpID (sort { $vpSum{$b} - $lastVPSum{$b} <=> $vpSum{$a} - $lastVPSum{$a} } keys %vpSum) {
    $spent = $vpSum{$vpID} - $lastVPSum{$vpID};
    next unless ($spent > 0);
    $classSpent = $vpClassSum{$vpClass{$vpID}} - $lastVPClassSum{$vpClass{$vpID}};
    print RAW sprintf("  VP %s (%s) spent %0.2fs on CPU (%0.1f%% of engine, %0.1f%% of class)\n",
      $vpID, $vpClass{$vpID}, $spent,
      $spent / $sumCPU * 100,
      $spent / $classSpent * 100);
  }
}

##############################################################################
sub processReadyQueues {
  $total_rdyQ = 0;
  @old_rstcb = ();
  %prev_rstcb = %current_rstcb; %current_rstcb = {};

  # parse the ready Q data FIRST (account for the 2 blank lines at the end)
  for ($i = 5; $i < $#onstat_rea - 2; ++$i) {
    @data=split(/\s+/, $onstat_rea[$i]);
    $rstcb = $data[3];
    $vpclass = $data[6];
    ++$total_rdyQ;
    if ($prev_rstcb{$rstcb} > 0) {
      $current_rstcb{$rstcb} = $prev_rstcb{$rstcb} + 1;
      ++$old_rstcb[$current_rstcb{$rstcb}];

      # dump out more information if it appears old
      if (($current_rstcb{$rstcb} - 1) * $refresh >= $staleReadyQ) {
       print RAW '='x76,"\n";
        print RAW "Old RSTCB($rstcb) in ready Q!\n";
        print RAW "  approx AGE is ", $current_rstcb{$rstcb} * $refresh ," secs\n";
        print RAW "  onstat -g rea -> ",$onstat_rea[$i],"\n";

        $onstat_act = (grep(/$vpclass/, @onstat_act))[0];
        print RAW "  onstag -g act -> $onstat_act\n";

        $onstat_u = (grep(/$rstcb/, @onstat_bufs))[0];
        print RAW "  onstat -u -> $onstat_u\n";

        $rea_tid = $data[1];
        print RAW "  Stack of ready thread (onstat -g stk $rea_tid)\n";
        print RAW join("  ",`onstat -g stk $rea_tid`),"\n";

        $act_tid = (split(/\s+/, $onstat_act))[1];
        $act_rstcb = (split(/\s+/, $onstat_act))[3];
        print RAW "  Stack of active thread (onstat -g stk $act_tid)\n";
        print RAW join("  ",`onstat -g stk $act_tid`),"\n";

        $rea_sid = (split(/\s+/, $onstat_u))[2];
        if (length($rea_sid) > 0) {
          print RAW "  Session of ready thread (onstat -g ses $rea_sid)\n";
          print RAW join("  ",`onstat -g ses $rea_sid`),"\n";
        } 
        else {
          print RAW "  Unable to track session of ready thread\n";
        }

        $act_sid = (split(/\s+/, (grep(/$act_rstcb/, @onstat_bufs))[0]))[2];
        if (length($act_sid) > 0) {
          print RAW "  Session of active thread (onstat -g ses $act_sid)\n";
          print RAW join("  ",`onstat -g ses $act_sid`),"\n";
        } 
	else {
          print RAW "  Unable to track session of active thread\n";
        }
      }
    } 
    else {
      $current_rstcb{$rstcb} = 1;
    }
  }

  # process old ready Q data
  $cmd_data .= sprintf("[readyQ=%d]", $total_rdyQ);
  print OUT "Number of sessions in ready Q = $total_rdyQ\n";

  for ($i = 0; $i < $#old_rstcb; ++$i) {
    if ($old_rstcb[$i] > 0) {
      $cmd_data .= sprintf("[oldReadyQ.%d=%d]", $i * $refresh, $old_rstcb[$i]);
      print OUT "Number of sessions in ready Q > ".($i - 1) * $refresh." secs = $old_rstcb[$i]\n";
    }
  }
}

############################################################################
sub processCheckPoint {

  # find the last checkpoint starting from the previous one
  if ($INF_LOG ne "NONE") {
    open(ONLINE_LOG, "< $INF_LOG") || die "Error opening Online Log:";
    seek(ONLINE_LOG, $chkptpos, 0) or $chkptpos = 0;
    while (<ONLINE_LOG>) {
      next unless (/ Checkpoint Completed:  duration was (\d+) seconds/);
      print OUT $_;
      $checkpointDur = $1;
      $chkptpos = tell(ONLINE_LOG);
      $cmd_data .= sprintf("[checkpoint=true]");
    }
    close(ONLINE_LOG);

    $cmd_data .= sprintf("[lastCheckpointDuration=%d]", $checkpointDur);
    print OUT "Last checkpoint duration = $checkpointDur secs\n";
  }

  # grab the shared memory size
  $onstat_rea[1] =~ / (\d+) Kbytes/;
  $cmd_data .= sprintf("[shmSizeKB=%d]", $1);
  print OUT "Shared memory size = $1 KB\n";

}

###########################################################################
sub processBuffers {
  $mutexes = 0;
  $bufwait = 0;
  $lockwait = 0;

  # parse the buffer data, only look for buff waits, mutexes, or
  # applications waiting on locks
  for ($i = 6; $i < $#onstat_bufs; ++$i) {
    @data=split(/\s+/, $onstat_bufs[$i]);
    $flags = $data[1];
    $sid = $data[2];
    $user = $data[3];
    $capture_sql = 0;

    # search in the flags field
    if ($flags =~ /S/) {
      ++$mutexes;
      ++$capture_sql;
    }

    if ($flags =~ /B/ && $flags !~ /^---P--B/) {
      ++$bufwait;
      ++$capture_sql;
    }

    if ($flags =~ /L/) {
      ++$lockwait;
      ++$capture_sql;
    }

    if ($capture_sql) {
      @onstat_sql=`onstat -g ses $sid`;
      print RAW "Mutext/Buffer/Lock: onstat -u ->\n$onstat_bufs[$i]";
      print RAW "onstat -g sql $sid ->\n";
      for ($j = 3; $j < $#onstat_sql; ++$j) {
        print RAW "$onstat_sql[$j]";
      }
    }
  }

  print OUT "mutexes = $mutexes\n";
  print OUT "buffer waits = $bufwait\n";
  print OUT "lock waits = $lockwait\n";
  $cmd_data .= sprintf("[mutexes=%d]", $mutexes);
  $cmd_data .= sprintf("[bufferWaits=%d]", $bufwait);
  $cmd_data .= sprintf("[lockWaits=%d]", $lockwait);

}

###########################################################################
sub processLocks {

  # parse the locks data, only print the active and total numbers
  @data=split(/\s+/, $onstat_lock[$#onstat_lock]);
  $active_locks = $data[1];
  $total_locks = $data[3];

  print OUT "active locks = $active_locks total locks = $total_locks\n";
}

#############################################################################
sub processSessions {
  %prev_hosts = %current_hosts; %current_hosts = {};
  %prev_memory = %current_memory; %current_memory = {};
  $last_total_mem = $total_mem;

  $total_mem = 0;
  $dropped_mem = 0;
  $total_sessions = 0; 

  $addedSum = 0;
  $droppedSum = 0;

  %added = {};
  %dropped = {};

  %current_host_memory = {};
  %host_connections = {};

  # parse the session data
  for ($i = 6; $i < $#onstat_ses - 1; ++$i) {
    @data=split(/\s+/, $onstat_ses[$i]);
    $sid = $data[0];
    $host = (split(/\./, $data[4]))[0];
    $mem = $data[6];
    $current_hosts{$sid} = $host;
    $current_memory{$sid} = $mem;
    $current_host_memory{$host} += $mem;

    $total_mem += $mem;
    ++$total_sessions;
    ++$host_connections{$host};
    if (length($prev_hosts{$sid}) == 0) {
      next unless (length($host) > 0);
      next if ($host =~ /HASH/);
      ++$added{$host};
      ++$addedSum;
    }

  }
  print OUT "Total Session Memory = $total_mem\n";
  print RAW "Total Sessions = $total_sessions\n";
  $cmd_data .= sprintf("[sessionMemory.totals=%d]", $total_mem);
  $cmd_data .= sprintf("[totalSessions=%d]", $total_sessions);

  # interpret the connection data
  foreach $host (keys %host_connections) {
    next if ($host =~ /HASH/ || $host =~ /-/);
    print RAW sprintf("Host = %8s Connections = %3d Memory = %d\n",
		      $host, $host_connections{$host}, 
		      $current_host_memory{$host});
    $cmd_data .= sprintf(" %s.connections=%d", $host, $host_connections{$host});
    $cmd_data .= sprintf(" %s.memory=%d", $host, $current_host_memory{$host});

  }

  return if ($firstRun);

  # interpret the session memory data
  foreach $sid (keys %prev_hosts) {
    if (length($current_hosts{$sid}) == 0) {
      $host = $prev_hosts{$sid};
      next unless (length($host) > 0);
      next if ($host =~ /HASH/);
      ++$dropped{$host};
      ++$droppedSum;
    }

    if ($current_memory{$sid} < $prev_memory{$sid}) {
      $dropped_mem += $prev_memory{$sid} - $current_memory{$sid};
    }
  }

  print OUT sprintf("Session Memory Added = %d\n", $total_mem - $last_total_mem + $dropped_mem);
  print OUT "Session Memory Dropped = $dropped_mem\n";
  $cmd_data .= sprintf("[sessionMemory.added=%d]", $total_mem - $last_total_mem + $dropped_mem);
  $cmd_data .= sprintf("[sessionMemory.dropped=%d]", $dropped_mem);

  # print the data in human format
  print OUT "Active Sessions = $total_sessions\n";
  print OUT "Added Sessions = $addedSum\n";
  foreach $host (keys %added) {
    next if ($host =~ /HASH/);
    $cmd_data .= sprintf("[%s.addedConnections=%d]", $host, $added{$host});
    print OUT "  ",$host," "x(12-length($host)),"\t",$added{$host},"\n";
  }

  print OUT "Dropped Sessions = $droppedSum\n";
  foreach $host (keys %dropped) {
    next if ($host =~ /HASH/);
    $cmd_data .= sprintf("[%s.droppedConnections=%d]", $host, $dropped{$host});
    print OUT "  ",$host," "x(12-length($host)),"\t",$dropped{$host},"\n";
  }

  $cmd_data .= sprintf("[ALL.addedConnections=%d]", $addedSum);
  $cmd_data .= sprintf("[ALL.droppedConnections=%d]", $droppedSum);

}

##############################################################################
sub processNetwork {

  for ($i = 0; $i <= $#netstat; ++$i) {
    @data=split(/\s+/, $netstat[$i]);
    $sendWindow = $data[2];
    $sendQ = $data[3];
    $recvWindow = $data[4];
    $recvQ = $data[5];
    if ($sendWindow < $minWindowSize ||
        $recvWindow < $minWindowSize) {
      ++$lowWindowSize;
      print RAW $netstat[$i];
    } 
    elsif ($sendQ > 0 || $recvQ > 0) {
      print RAW $netstat[$i];
      $outNetDataPending +=  $sendQ;
      $inNetDataPending  += $recvQ;
    }
    # print int($sendWindow / $winBucketSize),"$sendWindow,$recvWindow,$sendQ,$recvQ\n";

    if ($sendWindow == 0) {
      ++$sendWindowSize[0];
    } 
    else {
      ++$sendWindowSize[1 + int($sendWindow / $winBucketSize)];
    }

    if ($recvWindow == 0) {
      ++$recvWindowSize[0];
    } 
    else {
      ++$recvWindowSize[1 + int($recvWindow / $winBucketSize)];
    }

    if ($sendQ == 0) {
      ++$sendQueues[0];
    } 
    else {
      ++$sendQueues[1 + int($sendQ / $queueBucketSize)];
    }

    if ($recvQ ==0) {
      ++$recvQueues[0];
    } 
    else {
      ++$recvQueues[1 + int($recvQ / $queueBucketSize)];
    }
  }

  print RAW "Send Window Size histogram\n";
  for ($i = 0; $i <= $#sendWindowSize; ++$i) {
    next unless ($sendWindowSize[$i] > 0);
    if ($i == 0) {
      print RAW sprintf("       SendWinSize == 0 = %d\n", $sendWindowSize[$i]);
    } 
    else {
      print RAW sprintf("  %d < SendWinSize < %d = %d\n", ($i - 1) * $winBucketSize, $i * $winBucketSize, $sendWindowSize[$i]);
    }
  }

  print RAW "Receive Window Size histogram\n";
  for ($i = 0; $i <= $#recvWindowSize; ++$i) {
    next unless ($recvWindowSize[$i] > 0);
    if ($i == 0) {
      print RAW sprintf("       RecvWinSize == 0 = %d\n", $recvWindowSize[$i]);
    } 
    else {
      print RAW sprintf("  %d < RecvWinSize < %d = %d\n", ($i - 1) * $winBucketSize, $i * $winBucketSize, $recvWindowSize[$i]);
   }
  }

  print RAW "Send Queue Size histogram\n";
  for ($i = 0; $i <= $#sendQueues; ++$i) {
    next unless ($sendQueues[$i] > 0);
    if ($i == 0) {
      print RAW sprintf("       Send-Q == 0 = %d\n", $sendQueues[$i]);
    } 
    else {
      print RAW sprintf("  %d < Send-Q < %d = %d\n", ($i - 1) * $queueBucketSize, $i * $queueBucketSize, $sendQueues[$i]);
    }
  }

  print RAW "Receive Queue Size histogram\n";
  for ($i = 0; $i <= $#recvQueues; ++$i) {
    next unless ($recvQueues[$i] > 0);
    if ($i == 0) {
      print RAW sprintf("       Recv-Q == 0 = %d\n", $recvQueues[$i]);
    } 
    else {
      print RAW sprintf("  %d < Recv-Q < %d = %d\n", ($i - 1) * $queueBucketSize, $i * $queueBucketSize, $recvQueues[$i]);
    }
  }

  @sendWindowSize = ();
  @recvWindowSize = ();
  @sendQueues = ();
  @recvQueues = ();

  if ($lowWindowSize > 0) {
    print OUT "  connections with low window sizes (< $minWindowSize bytes) = $lowWindowSize\n";
    $cmd_data .= sprintf("[lowWindowSizeCnt=%s]", $lowWindowSize);
    $lowWindowSize = 0;
  }

  if ($outNetDataPending > 0) {
    print OUT "  outbound network data pending = $outNetDataPending bytes\n";
    $cmd_data .= sprintf("[outboundNetworkDataPending=%s]", $outNetDataPending);
    $outNetDataPending = 0;
  }

  if ($inNetDataPending > 0) {
    print OUT "  inbound network data pending = $inNetDataPending bytes\n";
    $cmd_data .= sprintf("[inboundNetworkDataPending=%s]", $inNetDataPending);
    $inNetDataPending = 0;
  }
}

#############################################################################
sub processLoad {

  # Get the load average from the system
  $load =~ /load average: ([\d\.]+)/;
  $sysLoadAvg = $1;
  print OUT "system load average = $sysLoadAvg\n";
  $cmd_data .= sprintf("[loadAverage=%s]", $sysLoadAvg);

}
##############################################################################
sub processVmstat {

  # Get RunQ, Blocked, Free Memory, %usr, %sys, %idle
  # Split the fourth line of the vmstat output.  The first two lines
  # are headers, and the third is invalid
  @vmdata = split / +/, $vmstat[3];
  print OUT sprintf("Free Memory = %d MB ", int $vmdata[5]/1024);
  print OUT "RunQ = $vmdata[1] ";
  print OUT "Blocked = $vmdata[2] ";
  print OUT "%Usr = $vmdata[20] ";
  print OUT "%Sys = $vmdata[21] ";
  print OUT "%Idle = $vmdata[22] ";
}

#
# Print a usage statement and exit.
#
sub usageexit {
  print "Usage: monses.pl -i instance\n";
  print "  instance = INFOMRIXSERVER\n";
  print "This script monitors Informix Sessions for problem SQL\n";
  exit;
}
