#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;
use Proc::Daemon;
#/pegs/logs/adsdevae01/tools_instance_1-gf3/developers_toolkit
#developers_toolkit-stats.log       developers_toolkit.log
#developers_toolkit-trans.log       developers_toolkit.log.2012-09-07

print "starting pid\n";

my $daemon = Proc::Daemon->new(
        work_dir     => '/home/bfausey/output',
        child_STDOUT => '/home/bfausey/output/output.file',
        pid_file     => 'pid.txt',
        exec_command => 'cat /pegs/logs/adsdevae01/tools_instance_1-gf3/developers_toolkit/developers_toolkit-stats.log | wc -l',
      # or:
      # exec_command => [ 'perl /home/my_script.pl', 'perl /home/my_other_script.pl' ],
    );
$KidPid = $daemon->Init;
print "daemon = " . $daemon->Status($KidPid) . " $KidPid\n";
exit(0);
