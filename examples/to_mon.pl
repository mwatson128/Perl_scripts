#!/usr/local/bin/perl
# (]$[) to_mon.pl:1.1 | CDATE=05/01/02 12:28:10
# This script counts timeouts from the runtime log and displays them 
# real time for monitoring with SiteScope.

@time = gmtime;
$day = $time[3] + 0;
# Based on user id, determine production or test environment
$id = `/usr/bin/id`;
$id =~ /\((.*)\) gid/;
$user = $1;
if ($user eq "usw") {
  $master_config="/prod/config/master.cfg";
  $timeoutdir = "/prod/perf/timeouts";
} 
elsif ($user eq "qa") {
  $master_config = "/qa/config/master.cfg";
  $timeoutdir = "/qa/perf/timeouts";
} 
else {
  print "This script needs to be run as qa or usw\n";
  exit;
}
$timeoutfile = sprintf "%s/tolog%d", $timeoutdir, $day;

@gdslist = qw "AA UA 1P 1A WB MS";
$gdslist = join " ", @gdslist; 

# Parse master.cfg and get a list of connections.
open MASTER, $master_config or die "Can't open $master_config.\n";
while ($line = <MASTER>) {
  if ($line !~ /^$|^#/) {
    $hold = "";
    while ($line =~ /\\$/) {
      chomp $line;
      chop $line;
      $hold = $hold . $line;
      $line=<MASTER>;
    }
    
    chomp $line;
    $hold = $hold . $line;
    if ($line =~ /{/) {
      chomp $line;
      chop $line;
      chop $line;
      $config_type = $line;
      %hold = ();
    } elsif ($line =~ / = /) {
      ($key, $value) = split / = /, $hold;
      $hold{$key} = $value;
    } else {
      if ($config_type eq "HRS_EQUIVALENCE") {
        $hrs_equi{$hold{PRIMARY_ID}} = $hold{HRS};
      }
    }
  }
}
close MASTER;

for $hrs (sort keys %hrs_equi) {
  push @hrslist, $hrs;
  $hrslist = $hrslist . " " . $hrs;
}

close STDOUT;
open STDOUT, "> $timeoutfile" or die "Can't open $timeoutfile.\n";
select STDOUT; 
$|=1;

while ($block=<STDIN>) {
  if ($block =~ /CTTM/) {
    @block = split /\[/, $block;
    for $line (@block) {
      if ($line =~ /CTTM/) {
        @line = split / +/, $line;
        ($junk, $hrs) = split /\:/, $line[10];
        ($junk, $gds) = split /\:/, $line[11];
        @ip = split //, $line[4];
        shift @ip;
        $hold = join "", @ip;
        ($ip, $junk) = split /-/, $hold;
        $total++;
        if ($ip =~ /^$hrs/) {
          $hrsto{$hrs}++;
        } else {
          $gdsto{$gds}++;
        }
      }
    }
  }
  @line = split / +/, $block;
  if ($line[2] =~ /\d\d\:\d\d\:\d\d/) {
    ($hour, $minute, $second) = split /\:/, $line[2];
  } else {
    ($hour, $minute, $second) = split /\:/, $line[3];
  }
  $currtime = $hour * 60 + $minute;
  if ($currtime > 1435) {
    print "I'm outtie!\n";
    exit;
  } elsif ($currtime > $lasttime) {
    for $hrs (@hrslist) {
      printf "%02d:%02d HRS=%s %d\n", $hour, $minute, $hrs, $hrsto{$hrs};
    }
    for $gds (@gdslist) {
      printf "%02d:%02d GDS=%s %d\n", $hour, $minute, $gds, $gdsto{$gds};
    }
    printf "%02d:%02d ALL-CTTM %d\n", $hour, $minute, $total;
    $lasttime = $currtime;
    $total = 0;
    %hrsto = ();
    %gdsto = ();
  }
}
  
