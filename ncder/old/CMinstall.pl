#! /usr/local/bin/perl
################################################################################
## Purpose: This is a simple utility to automate installation procedures for  ##
##          the CM group in the USW environment.  It expects a config file    ##
##          which will contain the data necessary to update specific files to ##
##          specific versions.  Version status is checked before and after    ##
##          each update in order to verify successful installation.           ##
##----------------------------------------------------------------------------##
## Input  : config file and user name (both are mandatory parameters)         ##
## Output : A log file is created that keeps track of all actions/output.     ##
##----------------------------------------------------------------------------##
## Author : Kevin Daniel (kevin.daniel@pegs.com)                              ##
## Date   : August 14, 2007 - initial version                                 ##
################################################################################
use POSIX;
use strict;
use Time::Local;


#########################################
#----------# Initializations #----------#
#########################################
$| = 1; #Turn off buffered output
my $today = strftime("%Y%m%d", gmtime); 
my $date = strftime("%A %B %d %Y %T GMT", gmtime);
my $cvs = "/usr/local/bin/cvs";
my $logfile = "logs/$today-install.log";
my $indent = "   ";
my $tab = $indent x 2;
my ($config, $env, $user);
my (@results, $permission, $status, $code, $working);
my ($line, @commands);
my $header = "HOSTNAME    OLD     NEW     FILE NAME        STATUS";
my $div = "==============================================================="; 
my ($host, $pathfile, $path, $file, $oldver, $newver);
chomp(my $localhost = `hostname`);
chomp(my $wkdir = `pwd`);
my $hlen = 10;
my $flen = 15;
my $olen = 6;
my $nlen = 6;


###########################################
#-------------# Begin  Main #-------------#
###########################################

## Open the log file for writing
open(LOG, ">>$logfile");

## Make sure a valid config file was given on the command line
if ($ARGV[0] ne "") {
  $config = "$ARGV[0]";
  ## A filename was given; now make sure it exists and is not empty
  if ((-e $config) && (!-z $config)) {
    ## Good - the file exists and has stuff in it
  } else {
    ## Bad - file is either empty or non-existent
    &dieGracefully("Error!  Config file: '$ARGV[0]' is either empty or doesn't exist.  Exiting.");
  }
} else {
  ## User forgot to pass in a config filename
  &dieGracefully("Error!  Parameter is missing - config filename!  Exiting.");
}

## Make sure a valid username was given on the command line
if ($ARGV[1] ne "") {
  $user = $ARGV[1];
} else {
  ## User forgot to pass in a username
  &dieGracefully("Error!  Parameter missing - username!  Exiting.");
}

## Read the config file and grab all the instructions from it
chomp(@commands = `cat $config`);

## Validate the config file contents
foreach $line (@commands) {
  if(scalar(split(/ /, $line)) != 4) {
    &dieGracefully("Error!  Invalid config entry:\n$tab'$line'.\nIncorrect number of fields.  Exiting.");
  }
}

################################################################################
## OK, all the validation stuff is done.  Now for the main body of the script ##
################################################################################
## Print header info
&display("***************************\n");
&display("* Begin File Installation *\n");
&display("***************************\n");
&display("$indent$date\n");
&display("$indent$header\n");
&display("$indent$div\n");

## Now loop through the config file and perform each requested action
foreach $line (@commands) {
  ($host, $pathfile, $oldver, $newver) = split(/ /, $line);
  $pathfile =~ /(.+)\/(.+)/;
  $path = $1;
  $file = $2;
  undef($working);
  undef($status);
  undef($code);

  ## Don't check the current version if this is a new file
  if ($oldver eq "NF") {
    $working = $oldver;
  } else {
    ## Check to make sure this host has the expected version
    $working = &CheckStatus("$host","$path","$file");
  }

  ## If the versions don't match, don't do anything else
  if ($working ne $oldver) {
    $status = "Problem!\n$tab-->Incorrect version before update - Expecting '$oldver', Found '$working'.";
  } else {

    ## Do the update
    chomp(@results = &DoUpdate("$host","$path","$file","$newver"));

    ## If the update worked, modify the status
    print LOG "$indent----->cvs update : begin output<-----\n";
    foreach $line (@results) {
      if ($line =~ /^(.) $file/) {
        $code = $1;
        if ($code =~ /[UP]/) { $status = "Success!"; }
      }
      print LOG "$tab$line\n";
    }
    print LOG "$indent----->cvs update : end output<-----\n";

    ## If the status is not 'Success', a problem occurred with the update
    if ($status !~ /Success!/) {
      $status = "Problem!\n$tab-->'cvs update' returned an unexpected update code - '$code'.";
    } else {

      ## Double check that the file was actually updated correctly
      $working = &CheckStatus("$host","$path","$file");
  
      ## If the versions don't match, update the status again
      if ($working ne $newver) {
        $status = "Problem!\n$tab-->Incorrect version after update - Expecting '$newver', Found '$working'.";
      } else {

        ## Version is good - now make sure the permissions are good too
        chomp($permission = &chmod($host, $path, $file));

        ## Make sure the chmod worked
        if ($permission != 755) {
          $status = "Problem!\n$tab-->File is installed, but could not change permissions.\n" .
                    "$tab-->Expecting '755', found  '$permission'.  Intervention may be needed.";
        }

      } #end if working ne newver

    } #end if status ne success

  } #end if working ne oldver

  ## Print the status of this file update
  &formattedPrint;
  &display("$status\n");

}

## Print the footer info
&display("******************************\n");
&display("* File Installation Complete *\n");
&display("******************************\n");

## Close the log file
close(LOG);

print "\nFor more details, see $logfile.\n";
exit;

##################################
## Print to screen and log file ##
##################################
sub display {
  my $string = shift(@_);
  print LOG "$string";
  print "$string";
}# End sub display ###############


##############################################
## Format the file information and print it ##
##############################################
sub formattedPrint {
  my $s = " ";
  my $hdiff = (length($host) < $hlen ? $hlen - length($host) : 1);
  my $odiff = (length($oldver) < $olen ? $olen - length($oldver) : 1);
  my $ndiff = (length($newver) < $nlen ? $nlen - length($newver) : 1);
  my $fdiff = (length($file) < $flen ? $flen - length($file) : 1);
  my $string  = $indent;
     $string .= $host . $s x $hdiff . $s x 2;
     $string .= $oldver . $s x $odiff . $s x 2;
     $string .= $newver . $s x $ndiff . $s x 2;
     $string .= $file . $s x $fdiff . $s x 2;
  &display("$string");
  print LOG "\n";
}


###############################################
## An error occurred.  Print it, and a usage ##
## statement, then close the log and exit.   ##
###############################################
sub dieGracefully {
  my $string = shift(@_);
  print LOG "$div\n";
  &display("\n$string\n");
  &display("\nUsage: CMinstall.pl configfile username\n\n");
  &display("Expected config file format:\n");
  &display("HOST PATH_and_FILENAME OLDVERSION NEWVERSION\n");
  print LOG "$div\n";
  close(LOG);
  exit;
}


###################################################
## Do a 'cvs status' on the file to see what the ##
## current version is.  If the host that we are  ##
## checking is the local host, ssh is not        ##
## necessary.  Return version num to the caller. ##
###################################################
sub CheckStatus {
  my $thishost = shift(@_);
  my $thispath = shift(@_);
  my $thisfile = shift(@_);
  my (@findings,$line,$wkver);

  ## If this host is the localhost, don't use ssh
  if ($thishost eq $localhost) {
    chdir($thispath);
    chomp(@findings = `$cvs status $thisfile 2>&1`);
    chdir($wkdir);
  } else {
    chomp(@findings = `ssh $user\@$thishost '. ./.cmprofile; date; hostname; cd $thispath; pwd; $cvs status $thisfile 2>&1' 2>&1`);
  }

  ## Scan the output to find the version number
  print LOG "$indent----->cvs status : begin output<-----\n";
  foreach $line (@findings) {
    if ($line =~ /Working revision:[^0-9]+([0-9.]+)/) { $wkver = $1; }
    print LOG "$tab$line\n";
  }
  print LOG "$indent----->cvs status : end output<-----\n";

  return($wkver);
}


######################################################
## Do a 'cvs update' on the file, bringing it up to ##
## the desired version number.  If the host that we ##
## are updating is the local host, ssh is not       ##
## necessary.  Return all results to the caller.    ##
######################################################
sub DoUpdate {
  my $thishost = shift(@_);
  my $thispath = shift(@_);
  my $thisfile = shift(@_);
  my $thisver  = shift(@_);
  my @findings;

  ## If this host is the localhost, don't use ssh
  if ($thishost eq $localhost) {
    chdir($thispath);
    chomp(@findings = `$cvs update -r$thisver $thisfile 2>&1`);
    chdir($wkdir);
  } else {
    chomp(@findings = `ssh $user\@$thishost '. ./.cmprofile; date; hostname; cd $thispath; pwd; $cvs update -r$thisver $thisfile 2>&1' 2>&1`);
  }

  return(@findings);
}


#####################################################
## Do a 'chmod 755' on the file.  If the host that ##
## we are updating is the local host, ssh is not   ##
## necessary.  Return all results to the caller.   ##
#####################################################
sub chmod {
  my $thishost = shift(@_);
  my $thispath = shift(@_);
  my $thisfile = shift(@_);
  my ($findings, @bits, $bit, $perm);
  my $modifier = 100;

  ## If this host is the localhost, don't use ssh
  if ($thishost eq $localhost) {
    chdir($thispath);
    system("chmod 755 $thispath/$thisfile 2>&1");
    chomp($findings = `ls -l $thispath/$thisfile 2>&1`);
    chdir($wkdir);
  } else {
    system("ssh $user\@$thishost '. ./.cmprofile; cd $thispath; chmod 755 $thisfile 2>&1' 2>&1");
    chomp($findings = `ssh $user\@$thishost '. ./.cmprofile; cd $thispath; ls -l $thisfile 2>&1' 2>&1`);
  }

  @bits = split(//, substr($findings, 0, 10));
  #-rwxr-xr-x   <--this is '755'
  foreach $bit (1..9) {
    if ($bits[$bit] eq "r") { $perm += (4*$modifier); }
    if ($bits[$bit] eq "w") { $perm += (2*$modifier); }
    if ($bits[$bit] eq "x") { $perm += $modifier; }
    if (!($bit % 3)) { $modifier /= 10; }
  }

  return($perm);
}
