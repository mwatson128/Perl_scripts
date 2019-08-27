#!/usr/local/bin/perl
use Time::Local;
use POSIX;

$INFO = 0;

chomp($local_host = `/bin/hostname`);
$base = "/home/mwatson";
$gnuplot = "$base/bin/gnuplot";
$ps2jpg = "$base/bin/ps2jpg";
$jpegtran = "$base/bin/jpegtran";


if ($ARGV[0] eq "help") { &Usage; }
if ($ARGV[0] eq "verbose") { $INFO = shift(@ARGV); }

## Now, graph it all
print "Plotting USW Prod TPS (config file is tmp/usw_prod_tps.config)\n";

&WriteConfig;
system("$gnuplot < usw_prod_tps.config");
#system("$ps2jpg usw_prod_tps.ps");
#system("cat usw_prod_tps.jpg | $jpegtran -rotate 90 > usw_prod_tps2.jpg 2>/dev/null");
#system("scp usw_prod_tps.jpg kdaniel\@sysmon:/web/docs/USW/tps/");

exit;

sub Usage {
  print "Usage: $0 [verbose] [YYYYMMDD] [-L hh:mm] [-R hh:mm]\n";
  die "Default is to use current date and time (window is 30 minutes)\n";
}


sub WriteConfig {
  undef(@static);

  push(@static, "set term postscript");
  push(@static, "set term postscript");
  push(@static, "set output \"usw_prod_tps.ps\"");
  push(@static, "set xdata time");
  push(@static, "set timefmt x \"%H:%M:%S\"");
  push(@static, "set format x \"%H:%M\"");
  push(@static, "set size .90,.55");
  push(@static, "set xtic auto");
  push(@static, "set ytic auto ");
  push(@static, "set title \"USW Volume\"");
  push(@static, "set xlabel \"Time\"");
  push(@static, "set ylabel \"Trans Per Second (TPS)\"");

  open (OUT, ">usw_prod_tps.config");
  print OUT join("\n", @static) . "\n";
#  print OUT "set out \"$base/UD/DC/tmpdemo/demo-$host.ps\"\n";
  #print OUT "set style line 1 lt 2 lw 2 pt 3 ps 0.5\n";
  print OUT "plot \"usw_stats-smoothed.txt\" using 1:7 t \"TPS ALL\" with lines, \\\n";
  print OUT "     \"usw_stats-smoothed.txt\" using 1:9 t \"TPS PALS\" with lines \n";
  close(OUT);
}

