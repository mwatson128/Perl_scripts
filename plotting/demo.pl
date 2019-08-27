#!/usr/local/bin/perl
use Time::Local;
use POSIX;

$xRange = 1800;
$yRange = 50;
$INFO = 0;
if ($ARGV[0] eq "help") { &Usage; }
if ($ARGV[0] eq "verbose") { $INFO = shift(@ARGV); }

## Check for required date parameter
if ($ARGV[0] =~ /^([0-9]{4})([0-9]{2})([0-9]{2})$/) {
  $YYYY = $1;
  $MM = $2;
  $DD = $3;
  shift(@ARGV);
} else {
  $YYYY = strftime("%Y", gmtime(time));
  $MM   = strftime("%m", gmtime(time));
  $DD   = strftime("%d", gmtime(time));
}

$RBhh = strftime("%H", gmtime(time));
$RBmm = strftime("%M", gmtime(time));
$LBhh = strftime("%H", gmtime(time-$xRange));
$LBmm = strftime("%M", gmtime(time-$xRange));
$NEWLB = "$LBhh:$LBmm";

## Check for optional Left and Right boundaries
if ($ARGV[0] eq "-L") { shift(@ARGV);
  if ($ARGV[0] =~ /(..:..)/) { $NEWLB = shift(@ARGV); } else { $NEWLB = "$LBhh:$LBmm"; }
}
if ($ARGV[0] eq "-R") { shift(@ARGV);
  if ($ARGV[0] =~ /(..:..)/) { $NEWRB = shift(@ARGV); } else { $NEWRB = "$RBhh:$RBmm"; }
}

## Graph Line Type (re-order color precedence)
my %lt = ("0" => "1",
          "1" => "2",
          "2" => "4",
          "3" => "3",
          "4" => "8",
          "5" => "9");

$TotalHosts = 18;
$LastHost = 2;
foreach $hid (1..$LastHost) {

  $fmt_hid = sprintf("%02d", $hid);
  $host = "udprodae$fmt_hid";
  $prepared = "tmpdemo/$host-prepared.txt";
  $smoothed = "tmpdemo/$host-smoothed.txt";
  $fins_smoother = "fins/fins_smoother";
  $timeout = 15;
  $threads = 1000;
  $path = "archive/$YYYY/$MM/$YYYY$MM$DD";
  chomp($local_host = `/bin/hostname`);
  $base = "/$local_host/capacity";
  $gnuplot = "$base/bin/gnuplot-4.2.4";
  $ps2jpg = "$base/bin/ps2jpg";
  $jpegtran = "$base/bin/jpegtran";


  ## Determine das/cluster/instance info
  if (($hid % 2) == 1) { $das = 1; } else { $das = 2; }
  $c1 = ($das * 2) - 1;
  $c2 = $das * 2;
  $inst = int(($hid+1)/2);
  $i1 = "$path-d$das"."c$c1\_instance_";
  $i2 = "$path-d$das"."c$c2\_instance_";
  $label1 = "d$das"."c$c1"."_instance_$inst";
  $label2 = "d$das"."c$c2"."_instance_$inst";

  ## Get only the last 1800 lines & put them in the 'prepared' file
  $cmd = "hunter clock time '$YYYY-$MM-$DD $NEWLB' for 30 minutes $i1$inst.txt > $prepared.1";
  print "$cmd\n";
  system($cmd);
  $cmd = "hunter clock time '$YYYY-$MM-$DD $NEWLB' for 30 minutes $i2$inst.txt > $prepared.2";
  print "$cmd\n";
  system($cmd);
  $cmd = "cat $prepared.1 $prepared.2 > $prepared";
  print "$cmd\n";
  system($cmd);

  ## Now smooth the prepared file (into 'smoothed' file)
  $cmd = "cat $prepared.1 | $fins_smoother tmpdemo/slog stdout $timeout $threads | time-spackle 1 '|.|.|.|.' '$YYYY-$MM-$DD $LBhh:$LBmm:00' '$YYYY-$MM-$DD $RBhh:$RBmm:00' > $smoothed.1";
  print "$cmd\n";
  system($cmd);
  $cmd = "cat $prepared.2 | $fins_smoother tmpdemo/slog stdout $timeout $threads | time-spackle 1 '|.|.|.|.' '$YYYY-$MM-$DD $LBhh:$LBmm:00' '$YYYY-$MM-$DD $RBhh:$RBmm:00' > $smoothed.2";
  print "$cmd\n";
  system($cmd);
  $cmd = "cat $prepared | $fins_smoother tmpdemo/slog stdout $timeout $threads | time-spackle 1 '|.|.|.|.' '$YYYY-$MM-$DD $LBhh:$LBmm:00' '$YYYY-$MM-$DD $RBhh:$RBmm:00' > $smoothed";
  print "$cmd\n";
  system($cmd);

  ## Now, graph it all
  print "Plotting $host (config file is tmpdemo/demo-$host.config)\n";

  undef(@labels);
  $end_time = timegm(0,$RBmm,$RBhh,$DD,$MM-1,$YYYY-1900);
  @labels = &GenerateLabels($end_time);
  $xTics = join(",", @labels);

  &WriteConfig;
  system("$gnuplot < tmpdemo/demo-$host.config >/dev/null 2>&1");
  system("$ps2jpg tmpdemo/demo-$host.ps 2>/dev/null");
  system("cat tmpdemo/demo-$host.jpg | $jpegtran -rotate 90 > tmpdemo/$host.jpg 2>/dev/null");
  system("scp tmpdemo/$host.jpg kdaniel\@sysmon:/web/docs/UD/DC/demo");
}

exit;

## Now, graph it all
print "Plotting DAS1\n";
&DASConfig(1);
system("$gnuplot < tmpdemo/demo-das1.config >/dev/null 2>&1");
system("$ps2jpg tmpdemo/demo-das1.ps 2>/dev/null");
system("cat tmpdemo/demo-das1.jpg | $jpegtran -rotate 90 > tmpdemo/demoDAS1.jpg 2>/dev/null");
system("scp tmpdemo/demoDAS1.jpg kdaniel\@sysmon:/web/docs/UD/DC/demo");

print "Plotting DAS2\n";
&DASConfig(2);
system("$gnuplot < tmpdemo/demo-das2.config >/dev/null 2>&1");
system("$ps2jpg tmpdemo/demo-das2.ps 2>/dev/null");
system("cat tmpdemo/demo-das2.jpg | $jpegtran -rotate 90 > tmpdemo/demoDAS2.jpg 2>/dev/null");
system("scp tmpdemo/demoDAS2.jpg kdaniel\@sysmon:/web/docs/UD/DC/demo");

exit;


sub Usage {
  print "Usage: $0 [verbose] [YYYYMMDD] [-L hh:mm] [-R hh:mm]\n";
  die "Default is to use current date and time (window is 30 minutes)\n";
}


sub GenerateLabels {
  my $step = 5;
  my $backup = $step * 60;
  my $tick = $xRange;
  my $time = shift(@_);
  my ($m,$d,@lbls);
  while ($tick >= 0) {
    $h = strftime("%H", gmtime($time));
    $m = strftime("%M", gmtime($time));
    unshift(@lbls, "'$h:$m' $tick");
    $time -= $backup;
    $tick -= $backup;
  }
  return(@lbls);
} #end sub GenerateLabels


sub WriteConfig {
  undef(@static);
  push(@static, "set term postscript color solid");
  push(@static, "set datafile commentschars \"*\"");
  push(@static, "set datafile separator \"|\"");
  push(@static, "set xlabel \"Time (GMT)\"");
  push(@static, "set ylabel \"Duty Cycle\"");
  push(@static, "set title \"UD - $host - $YYYY-$MM-$DD\"");
  push(@static, "set xtics ($xTics)");
  push(@static, "set xrange [0:$xRange]");
  push(@static, "set format x \"%b\'%y\"");
  push(@static, "set format y \"%Q\"");
  push(@static, "set timefmt \"%Y%m%d\"");
  push(@static, "set yrange [0:$yRange]");
  push(@static, "set tmargin 0");
  push(@static, "set lmargin 3");
  push(@static, "set rmargin 15");
  push(@static, "set bmargin 20");
  push(@static, "set grid");
  push(@static, "set time");
  push(@static, "set key center top horizontal");

  open (OUT, ">tmpdemo/demo-$host.config");
  print OUT join("\n", @static) . "\n";
  print OUT "set out \"$base/UD/DC/tmpdemo/demo-$host.ps\"\n";
  print OUT "set style line 1 lt 2 lw 2 pt 3 ps 0.5\n";
  print OUT "plot \"$base/UD/DC/tmpdemo/$host-smoothed.txt.1\" using 4 ti \"$label1\" w li 1, \\\n";
  print OUT "     \"$base/UD/DC/tmpdemo/$host-smoothed.txt.2\" using 4 ti \"$label2\" w li 2\n";
  close(OUT);

}

sub DASConfig {
  $mydas = shift(@_);

  undef(@static);
  push(@static, "set term postscript color solid");
  push(@static, "set datafile commentschars \"*\"");
  push(@static, "set datafile separator \"|\"");
  push(@static, "set xlabel \"Time (GMT)\" offset 0,-2");
  push(@static, "set ylabel \"Duty Cycle\"");
  push(@static, "set title \"UD - DAS $mydas - $YYYY-$MM-$DD\"");
  push(@static, "set xtics ($xTics)");
  push(@static, "set xrange [0:$xRange]");
  push(@static, "set format x \"%b\'%y\"");
  push(@static, "set format y \"%Q\"");
  push(@static, "set timefmt \"%Y%m%d\"");
  push(@static, "set yrange [0:$yRange]");
  push(@static, "set tmargin 0");
  push(@static, "set lmargin 3");
  push(@static, "set rmargin 15");
  push(@static, "set bmargin 20");
  push(@static, "set grid");
  push(@static, "set time");
  push(@static, "set key center top horizontal");

  open (OUT, ">tmpdemo/demo-das$mydas.config");
  print OUT join("\n", @static) . "\n";
  print OUT "set out \"$base/UD/DC/tmpdemo/demo-das$mydas.ps\"\n";
  print OUT "set style line 1 lt 2 lw 2 pt 3 ps 0.5\n";
  print OUT "plot";
  $idx = 0;
  $Limit = $LastHost - 2;
  $last = $mydas + $Limit;
  for ($n = $mydas; $n <= $Limit; $n+=2) {
    $fmt = sprintf("%02d", $n);
    print OUT " \"$base/UD/DC/tmpdemo/udprodae$fmt-smoothed.txt\" using 4 ti \"udprodae$fmt\" w li $lt{$idx},\\\n";
    $idx = ($idx+1)%6;
  }
  print OUT " \"$base/UD/DC/tmpdemo/udprodae$last-smoothed.txt\" using 4 ti \"udprodae$last\" w li $lt{$idx}\n";
  close(OUT);

}
