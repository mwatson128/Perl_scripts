#!/bin/perl
# Program that takes uptime reading then sleeps for 60 sceonds time,
# this continues for on hour. Reading once a minute for one hour.
# 
# (]$[) chkut.pl:1.8 | CDATE=03/18/03 22:19:43

$month = `date -u +%m%y`;
chomp($month);

# Get username
$id = "/usr/bin/id";
$username = `$id | sed 's/(/ /' | sed 's/)/ /' | cut -f2 -d' '`;
chomp $username;

# Get system name
chomp ($sysname = `/usr/bin/uname -n | cut -d . -f 1`);

#Output file.
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime();
$logprefix = "uptime.";
$g_year = $year % 100;
$filename = sprintf("%s%02d%02d%02d", $logprefix, $mon + 1, $mday, $g_year);

if ($username eq "qa") {
  if ($sysname =~ /^usw|^tusw|^dhsc/) {
    if (! -d "/qa/perf/kv/$month") {
      qx(mkdir /qa/perf/kv/$month); 
    }
    chdir "/qa/perf/kv/$month";
  }
  else {
    if (! -d "/usr/usw/qa/kv/$month") {
      qx(mkdir /usr/usw/qa/kv/$month); 
    }
    chdir "/usr/usw/qa/kv/$month";
  }
}
elsif ($username eq "usw") {
  if ($sysname =~ /^usw|^tusw|^dhsc/) {
    if (! -d "/${sysname}/perf/kv/$month") {
      qx(mkdir /${sysname}/perf/kv/$month);
    }
    chdir "/${sysname}/perf/kv/$month";
  }
  else {
    if (! -d "/usr2/usw/perf/kv/$month") {
      qx(mkdir /usr2/usw/perf/kv/$month);
    }
    chdir "/usr2/usw/perf/kv/$month";
  }
}
else {
  die "user $username, not authorized to run this script.\n";
}

open OLOG, ">> $filename" or die "can't open Ouput log: %filename. \n";
select OLOG; $| = 1;

for ($i = 0; $i < 60; $i++) {

  ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime();
  $date = sprintf("%02d/%02d/%04d %02d:%02d:%02d", $mon + 1, $mday,
                  $year + 1900, $hour, $min, $sec);
  $ut_cmd = `uptime`;
  chomp $ut_cmd;

  @info = split "load", $ut_cmd;
  print OLOG "$date   |   load", $info[1], "\n";
  sleep (60);

}

close OLOG;

