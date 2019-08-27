#!/usr/bin/perl -w
###########################################################################
#
# Perl script to automate the data gathering needed to compile Month end
# Ultraswitch billing.
#
###########################################################################

$MAX_PROCS = 10;
$numtimes = 0;

# Log which chain we're running.
print "PID of Parent $$ \n";

# Produce the performance reports
# Gets tricky.  We need to fork several subprocesses so they
# execute simultaneously.

while ($numtimes < 70) {

  $num_perfs = `ps -a | grep -c do_test`;
  chomp $num_perfs;
  if ($num_perfs < $MAX_PROCS) {

    if ( $pid1 = fork) { 
      # Will always be true, unless in child.
      $SIG{CHLD} = 'IGNORE'; 
    }
    elsif (defined $pid1) {
      # This executes in the child process.
      print "this is Process number; $numtimes\n";
      qx(do_test);
      exit;
    }
  }
  else {
    while ($num_perfs >= $MAX_PROCS) {
      sleep(10);
      $num_perfs = `ps -a | grep -c do_test`;
      chomp $num_perfs;
    }

    if ($pid1 = fork) {

      # Will always be true, unless in child.
      $SIG{CHLD} = 'IGNORE'; 
    }
    elsif (defined $pid1) {

      # This executes in the child process.
      print "this is Process number; $numtimes\n";
      qx(do_test);
      exit;
    }
  }
  $numtimes++;
}
