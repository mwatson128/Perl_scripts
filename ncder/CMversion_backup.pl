#! /usr/local/bin/perl
################################################################################
## Purpose: This is a simple utility to backup current versions running in    ##
##          production when activated.  It audits the USW Prod boxes and      ##
##          writes versions to a file that can be used to repopulate prod     ##
##          if any thing should happen to remove the files there.
##----------------------------------------------------------------------------##
## Input  : username (mandatory parameters)                                   ##
## Output : A config file with data and a log file with all actions/output.   ##
##----------------------------------------------------------------------------##
## Author : Mike Watson  (mike.watson@pegs.com)                               ##
################################################################################
use POSIX;
use Time::Local;

#########################################
#----------# Initializations #----------#
#########################################
$| = 1;       #Turn off buffered output
my $today   = strftime("%Y%m%d", gmtime); 
my $date    = strftime("%A %B %d %Y %T GMT", gmtime);
my $logfile = "backup/logs/$today-buildconfig.log";
my $indent  = "   ";
#my $tab     = $indent x 2;
#my $header  = "ACTION   HOSTNAME    OLD       NEW       PATH/FILENAME";
#my $div     = "==================================================================="; 
my $hlen    = 10;
my $wlen    = 8;
my $nlen    = 8;
my %paths;
my ($h, $p, $arg);
my (%hosts, $list, $user, $line, @list, $config);
my (@results, $repver, $returncode, $working, $exists);
my ($host, $pathfile, $path, $file, $newver, $action, $repositorypath);
chomp(my $localhost = `hostname`);
chomp(my $wkdir = `pwd`);


###########################################
#-------------# Begin  Main #-------------#
###########################################

## Open the log file for writing
open(LOG, ">>$logfile");

## Make sure a valid username was given on the command line
if ($ARGV[0] ne "") {
  $user = shift(@ARGV);
} else {
  ## User forgot to pass in a username
  &dieGracefully("Error!  Parameter missing - username!  Exiting.");
}

## Build the config filename and open it
$config = "backup/backup${today}.config";
open(CONFIG, ">$config");

## Initialize the host list:
$statsub = "/tmp/statsub.cfg";
@ceval = `grep TCPSES $statsub | grep Child`;

if ($ceval[0]) {
  foreach $ln (@ceval) {
    @tmp1 = split /\//, $ln;
    if ($tmp1[1] =~ /USW/) {
      $tpe = lc ("USW" . $tmp1[2]);
      $hosts{$tpe} = 0;
    }
    else {
      ($ce, @rest) = split / - /, $tmp1[2];
      $lc_ce = lc $ce;
      $hosts{$lc_ce} = 1;
    }
  }
}

## Valide that each host is reachable
foreach $h (sort keys %hosts) {
  chomp($exists = `ping $h`);
  if ($exists !~ /alive/) {
    &dieGracefully("Error!  Could not ping '$h'.  Exiting.");
  }
}

################################################################################
## OK, all the validation stuff is done.  Now for the main body of the script ##
################################################################################

## Loop through each entry from the list
foreach $h (sort keys %hosts) {
  next if !($hosts{$h});
  undef($working);
  undef($repver);
  undef($returncode);
  undef($repositorypath);
  $action = "Adding :";

  # set path and files
  $path = "/pegs/$h/uswbin";
  @files = `ssh $h "cd $path; /bin/ls -d * | grep -v CVS"`;

  foreach $fl (@files) {
    chomp $fl;

    ## Check the current version of this file
    ($working,$repver,$repositorypath) = &CheckStatus($h,$path,$fl);
    next if ($working eq "No entry");

    ## Print the output for this host/file combination
    &formattedPrint($h,$path,$fl,$working);
  }
} #end foreach list item
  
## Close the log and config files
close(LOG);
close(CONFIG);

print "\nFor more details, see $logfile.\n";
exit;

##################################
## Print to screen and log file ##
##################################
sub display {
  my $string = shift(@_);
  print CONFIG "$string";
}# End sub display ###############

##############################################
## Format the file information and print it ##
##############################################
sub formattedPrint {
  my $host = shift(@_);
  my $path = shift(@_);
  my $file = shift(@_);
  my $version = shift(@_);
  my $string = "$host ${path}/${file} $version";
  &display("$string\n");
}

###############################################
## An error occurred.  Print it, and a usage ##
## statement, then close the log and exit.   ##
###############################################
sub dieGracefully {
  my $string = shift(@_);
  print LOG "$div\n";
  &display("\n$string\n");
  &display("\nUsage: CMversion_backup.pl username\n\n");
  &display("Expected list file format:\n");
  &display("HOST PATH_and_FILENAME NEWVERSION\n");
  print LOG "$div\n";
  close(LOG);
  exit;
}

###################################################
## Do a 'cvs status' on the file to see what the ##
## current version is.  If the host that we are  ##
## checking is the local host, ssh is not        ##
## necessary.  Return the working revision, the  ##
## repository revision, and the repository path  ##
## to the caller.                                ##
###################################################
sub CheckStatus {
  my $thishost = shift(@_);
  my $thispath = shift(@_);
  my $thisfile = shift(@_);
  my (@findings,$line,$wkver,$rver,$rpath);

  ## If this host is the localhost, don't use ssh
  if ($thishost eq $localhost) {
    chdir($thispath);
    chomp(@findings = `cvs status $thisfile 2>&1`);
    chdir($wkdir);
  } else {
    chomp(@findings = `ssh $user\@$thishost '. ./.cmprofile; date; hostname; cd $thispath; pwd; cvs status $thisfile 2>&1' 2>&1`);
  }

  ## Scan the output to find the version number and status
  foreach $line (@findings) {
    if ($line =~ /Working revision:[^0-9]+([0-9.]+)/) { $wkver = $1; }
    if ($line =~ /Working revision:.+(No entry)/) { $wkver = $1; }
    if ($line =~ /Repository revision:[^0-9]+([0-9.]+).+\/vc\/cvsroot\/(.+)\/$thisfile/) {
      $rver = $1;
      $rpath = $2;
     }
  }

  return($wkver,$rver,$rpath);
}


