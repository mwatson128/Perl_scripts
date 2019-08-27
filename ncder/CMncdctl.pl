#! /usr/local/bin/perl
################################################################################
## Purpose: This is a simple utility to send ncdctl commands to running       ##
##          processes in production. Given a config file with IP's and        ##
##          commands it will send those commands to the given CE.             ##
##----------------------------------------------------------------------------##
## Input  : config-file (mandatory parameters)                                ##
## Output : A config file with data and a log file with all actions/output.   ##
##----------------------------------------------------------------------------##
## Author : Mike Watson  (mike.watson@pegs.com)                               ##
################################################################################
use POSIX;
use Time::Local;
use Getopt::Std;

#########################################
#----------# Initializations #----------#
#########################################
$| = 1;       #Turn off buffered output
my $today   = strftime("%Y%m%d", gmtime); 
my $logfile = "logs/$today-ncdctl.log";
chomp(my $zone = `uname -n`);
chomp(my $t_date = `date`);

$header1 = "==============================================================";

# Error conditions we know of
my $config_dnexist = "Error!  Config file empty or doesn\'t exist, EXIT";
my $config_miss = "Error! Parameter cfg filename missing, EXIT";
my $config_dno = "Error!  Not able to open config file, EXIT";

my ($h, $p, $arg);
my (%hosts, $list, $user, $config);
my ($host, $pathfile, $path, $file, $newver, $action, $repositorypath);
my $print_cnt = 0;

# Sub definitions
sub display;
sub dieGracefully;

###########################################
#-------------# Begin  Main #-------------#
###########################################

## Open the log file for writing
open(LOG, ">>$logfile");
display "$header1\n";
display "$t_date\n";
display "$header1\n";

getopts('ht');

if ($opt_h) {
  &dieGracefully("USAGE EXIT!");
}

## Make sure a valid config file was given on the command line
if ($ARGV[0] ne "") {
  $config = "$ARGV[0]";
  ## A filename was given; now make sure it exists and is not empty
  if ((-e $config) && (!-z $config)) {
    ## Good, files here.
  } 
  else {
    &dieGracefully($config_dnexist);
  }
} 
else {
  &dieGracefully($config_miss);
}

## Read in the config file and do ncdctl's
open CONFIG, "<$config" or &dieGracefully($config_dno);

###############################################################
## OK, all the validation stuff is done.  
## Now for the main body of the script ##
###############################################################

## Loop through each line of config, figure out the machine, and 
##   send the ncdctl to that machine and IP.
$print_cnt = 0;
while (<CONFIG>) {
  chomp;
  next if /^#|^$/;

  # Format of the config file?
  # machine connection command
  ($machine, $connection, @command) = split / /;

  $ncd_cmd = join(" ", @command);
  $ncd = "/pegs/knet/knet2.2.6.24/runtime/bin/ncdctl";

  ## setup the ncdctl command for this IP, this machine and this option.
  $PACKAGE = sprintf ("ssh %s %s -r -d %s %s", 
                      $machine, $ncd, $connection, $ncd_cmd);
  $PRINT_PACKAGE = sprintf ("ssh %s %s -r -d %s %s", 
                      $machine, ncdctl, $connection, $ncd_cmd);

  ## Run ncdctl command, log result
  
  if ($opt_t) {
    $print_cnt or display " Displaying instead of doing ncdctl's:\n";
    $print_cnt++;
    display "   $PRINT_PACKAGE\n";
  }
  else {

    $rv = system ($PACKAGE);
    if ($rv) {
      display " PROBLEM! - update returned error $rv\n\t$PRINT_PACKAGE\n";
    }
    else {
      display " SUCCESS! - update was succesfull\n\t$PRINT_PACKAGE\n";
    }
  }
} # End while config
  
## Close the log and config files
display "$header1\n";
close(LOG);
close(CONFIG);
exit;

##################################
## Print to screen and log file ##
##################################
sub display {
  my $string = shift(@_);
  print LOG "$string";
  print "$string";
}# End sub display ###############

###############################################
## An error occurred.  Print it, and a usage ##
## statement, then close the log and exit.   ##
###############################################
sub dieGracefully {
  my $string = shift(@_);
  print LOG "$div\n";
  &display("\n$string\n");
  &display("\nUsage: CMBncder.pl listfile\n\n");
  &display("Expected list file format:\n");
  &display("HOST CONNECTION COMMAND_to_RUN\n");
  print LOG "$div\n";
  close(LOG);
  exit;
}

