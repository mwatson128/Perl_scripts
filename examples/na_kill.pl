#!/bin/perl

################
# Variables
################
$td = `/bin/date`;
@svcs = `/bin/svcs -p`;
chomp ($zone = `uname -n`);
$maillist = "pedpg\@pegs.com";
$ENV{TZ} = 'UTC';
#$maillist = "mike.watson\@pegs.com";

$tell_age = 4;
$kill_age = 15;

# number of  log files
$num_logs = 4;

# Defines
$LOG_OUT = 0;

$JP_CNT =  $num_logs +1;
$JP_PID1 = $num_logs +2;
$JP_PID2 = $num_logs +3;
$JP_PID3 = $num_logs +4;
# More ?

$got_na = 0;
$email_needed = 0;

$header =  "-" x 70;
$header .=  "\n $td \n";

# Check log file write times for staleness
$log = "uswota/uswota-trans.log";
@trans_files = `ls -1 /pegs/logs/$zone/otadas??/d?c?_??/$log`;

foreach $filename (@trans_files) {
  chomp $filename;

  $filename =~ /d(\d)c(\d)_\d\d/;
  $na_name = "node_agent-" . $1;
  $cluster_num = $2;

  # save the filename to use in email
  $fname_hash{$cluster_num} = $filename;

  # Get last read and write times
  ($readtime, $writetime) = (stat($filename))[8,9];
  $cur_time = time();

  # Calculate how stale the file was. 
  $min_ago = ($cur_time - $writetime) / 60;
  $rounded_min_ago = sprintf("%d", $min_ago);

  $na_hash{$na_name}[$cluster_num] = $rounded_min_ago;
}

# Now check the SVCS for hung processes
foreach $node (@svcs) {
  chomp $node;
 
  # First line is the node agent line, capture info
  # example - svc:/application/SUNWappserver/uswprodce15_node_agent-2:default
  if ($node =~ /(\w+)_(node_agent-\d):/) {
    $box = $1;
    $na_name = $2;
    $na_hash{$na_name}[$JP_CNT] = 0;
    $got_na = 1;
    $jp_index = $num_logs + 2;
    $na_hash{$na_name}[$LOG_OUT] = "Node agent ${box}_$na_name \n";
  }
  # If weve gotten to the node agent (NA) line, ($got_na is set) then 
  # process the java children that belong to this NA.
  # example: "       Apr_17        376 java"
  elsif ($got_na) {
    if ($node =~ / java$/) {
      @javaline = split (/ +/, $node);    
      $jps_line = `/usr/jdk/jdk1.6.0_21/bin/jps | grep $javaline[2]`;
      $na_hash{$na_name}[$LOG_OUT] .= " $jps_line";
      $na_hash{$na_name}[$JP_CNT] += 1;
      $na_hash{$na_name}[$jp_index] = $javaline[2];
      $jp_index += 1;
    }
    else {
      $got_na = 0;
    }
  }
}
    
foreach $na_name (sort keys %na_hash) {
      
  # Name of the process to disable
  $na_cycle_name = $box . "_" . $na_name;
  
  # Calculate oldest log time
  $na_oldest_time = 0;
  for($i = 1; $i <= $num_logs; $i++) {
    $log_age = $na_hash{$na_name}[$i];
    if (defined $log_age) {
      $na_hash{$na_name}[0] .= " $fname_hash{$i} is $log_age old.\n";
    }
    if ($log_age > $na_oldest_time) {
      $na_oldest_time = $log_age;
    }
  }

  # Test oldest log time against defines
  if ($na_oldest_time >= $tell_age) {
    $na_hash{$na_name}[0] .= " A log is more than $tell_age minutes old.\n";
    if ($na_oldest_time > $kill_age) {
      $na_hash{$na_name}[0] .= " A log is more than $kill_age minutes old.\n";
    }
  }

  $non_standard = 0;
  # Print the number of Java process 
  $na_hash{$na_name}[0] .= " There are $na_hash{$na_name}[$JP_CNT] ";
  $na_hash{$na_name}[0] .= "java processes. \n";
  if (2 <= $na_hash{$na_name}[$JP_CNT]) {
    $non_standard = 1;
  }

  # Check number of java processes
  # For java processes <= 1 and log older than tell_age cycle
  #$do_cycle = 0;
  #if ($na_hash{$na_name}[$JP_CNT] <= 1) {
  #  if ($na_oldest_time > $tell_age) {
  #    $do_cycle = 1;
  #  }
  #}
  # or if logs are older than kill_age 
  #elsif ($na_oldest_time > $kill_age) {
  #  $do_cycle = 1;
  #}

  # Experimenting now with if logs are older than 5 mins, cycle
  $do_cycle = 0;
  if ($na_oldest_time >= $tell_age) {
    $do_cycle = 1;
  }

  if ($do_cycle) {
    # Reset node agent and kill hung instance.
    system "/usr/sbin/svcadm disable $na_cycle_name";
    if ($na_hash{$na_name}[$JP_CNT] == 1) {
      system "kill -9 $na_hash{$na_name}[$JP_PID1]";
    }
    elsif ($na_hash{$na_name}[$JP_CNT] == 2) {
      system "kill -9 $na_hash{$na_name}[$JP_PID1]";
      system "kill -9 $na_hash{$na_name}[$JP_PID2]";
    }
    elsif ($na_hash{$na_name}[$JP_CNT] == 3) {
      system "kill -9 $na_hash{$na_name}[$JP_PID1]";
      system "kill -9 $na_hash{$na_name}[$JP_PID2]";
      system "kill -9 $na_hash{$na_name}[$JP_PID3]";
    }
    system "/usr/sbin/svcadm enable $na_cycle_name";

    $email_needed = 1;
    $na_hash{$na_name}[0] .= "Node Agent $na_name has been cycled to ";
    $na_hash{$na_name}[0] .= "alleviate the hang.\n";
    if ($non_standard) {
      $subj_email = "Non Standard Node Agent $na_cycle_name cycle";
    }
    else {
      $subj_email = "Regular Node Agent $na_cycle_name cycle";
    }
  }
}
 
if ($email_needed) {
  # Open mail pipe
  open MAIL, "| /bin/mailx -s \"${subj_email}\" $maillist";
  printf MAIL $header;
  foreach $na_name (sort keys %na_hash) {
    printf MAIL $na_hash{$na_name}[0];
    printf MAIL "\n";
  }
  close MAIL;

  # Call stats reporter and put it in he background
  qx(nohup /pegs/${zone}/tostats/stats_gather.sh &);
}

open LOG, ">> /home/sun1/na_kill.log";
printf LOG $header;
foreach $na_name (sort keys %na_hash) {
  printf LOG $na_hash{$na_name}[0];
  printf LOG "\n";
}
close LOG;


