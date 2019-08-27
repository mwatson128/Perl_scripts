#!/usr/bin/perl
# (]$[) ipmchk.pl:1.3 | CDATE=02/15/08 08:32:46
######################################################################
# Purpose: Checks for processes that use too much memory 
######################################################################

######################################################################
# General config and variable setup 
######################################################################

sub init_stats;
sub parse_file;
sub mail_file;

########################
# Generate Environment #
########################
$ENV{PATH}="/usr/local/bin:/bin:/usr/bin";
$machine=`uname -n`;
chomp $machine;
$uid=`id | cut -d"(" -f2 | cut -d")" -f1`;
chomp $uid;
$recipients="pedpg\@pegs.com";
$mailprog = "/bin/mail";
$files_found=0;
$pid=0;
$sz=0;
$name=0;
$warn_limit=50000
$err_limit=75000

#######################################################
# Main                                                #
#######################################################

# Execute command
init_stats ();

# Parse file
parse_file ();

# Mail the file
mail_file ();

#######################################################
# Create directory variables based on uid and machine.
#######################################################
sub init_stats {
  if ($uid eq "usw") {
    @ps_o = qx(ps -lyuusw);
  } 
  elsif ($uid eq "qa") {
    @ps_o = qx(ps -lyuqa);
  } 
  else {
    print STDERR "Incorrect login ($uid) on machine ($machine).\n";
    exit 1;
  }

}

#########################################################
# Parse file
#########################################################
sub parse_file {

  foreach $line (@ps_o) {
  
    chomp $line;

    #Format of file 
    #($sp, $f, $s, $uid, $pid, $ppid, $c, $pri, $ni, 
    # $addr, $sz, $wchan, $tty, $time, $name) = split /\ +/, $line;
    
    @op = split /\ +/, $line;
    if ($op[3] ne "PID") {
      $pid = $op[3];
      $sz = $op[9];
      $name = $op[13];
      
      compute_size_file();
    }
    
  }
}

#########################################################
# Compute Size File
#########################################################
sub compute_size_file {

  if ($sz) {
    if ($warn_limit < $sz && $err_limit > $sz ) {
      print "Process= $pid $name, size= $sz, Monitor for growth.\n";
      $outlier[$files_found++] = "Process= $pid $name, size= $sz, Monitor for growth.\n";
    }
    elsif ( $err_limit < $sz ) {
      print "Process= $pid $name, size= $sz, Check immediately!\n";
      $outlier[$files_found++] = "Process= $pid $name, size= $sz, Check immediately!\n";
    }
  } 
 
}

##############################
# Send mail out to recipients
##############################
sub mail_file {
  if ($files_found > 0) {

    open (MAIL, "|$mailprog $recipients") || die "Can't open $mailprog!\n";
    print MAIL "To: $recipients\n";
    print MAIL "Subject: Excessive size alert for $machine\n\n"; 
    print MAIL @outlier;
    close (MAIL);

  }
}
