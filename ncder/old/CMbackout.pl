#! /usr/local/bin/perl
################################################################################
## Purpose: This is a simple utility to automate backout procedures for the   ##
##          CM group in the USW environment.  It expects a config file which  ##
##          will contain the data necessary to revert specific files back to  ##
##          their previouss versions.  Version status is checked before and   ##
##          after each update in order to verify successful backout.          ##
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
my $today   = strftime("%Y%m%d", gmtime); 
my $date    = strftime("%A %B %d %Y %T GMT", gmtime);
my $logfile = "logs/$today-backout.log";
my $indent  = "   ";
my $tab     = $indent x 2;
my $header  = "HOSTNAME    VERSION     FILE NAME        STATUS";
my $div     = "==============================================================="; 
my $hlen    = 10;
my $flen    = 15;
my $olen    = 10;
my ($config, $env, $user);
my (@results, $status, $code, $working, $exists);
my ($line, @commands);
my ($host, $pathfile, $path, $file, $oldver, $newver);
chomp(my $localhost = `hostname`);
chomp(my $wkdir = `pwd`);
my %environment = ("uat"   => "uat",
                   "qa"    => "qa",
                   "dev"   => "kdaniel",
                   "stage" => "chrism",
                   "prod"  => "usw");
my $valid = "[" . join("|", sort(keys(%environment))) . "]";


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
&display("**********************\n");
&display("* Begin File Backout *\n");
&display("**********************\n");
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

  ## If we are trying to backout a new file that failed to install in the first
  ## place, then it will not exist.  This checks to make sure the file is there
  ## before we do anything else to it.
  $exists = &CheckFile("$host","$path","$file");

  ## So the file doesn't exist.  Should it?
  if (!$exists) {

    ## If the oldver was "NF", then it's ok that the file is missing
    if ($oldver eq "NF") {
      $oldver = "deleted";
      $status = "Success!\n$tab-->New file '$file' has already been removed from '$host'.";
    } else {

      ## Uh-oh - we lost a file that should still be there.  We should go and
      ## try to get the old version that was supposed to be there before we
      ## did the install.
      chomp(@results = &DoUpdate("$host","$path","$file","$oldver"));
      
      ## If the update worked, modify the status
      print LOG "$indent----->cvs update : begin output<-----\n";
      foreach $line (@results) {
        if ($line =~ /^(.) $file/) {
          $code = $1;
          if ($code =~ /[UP]/) {
            $status = "Success!\n$tab-->Missing file '$file' has been restored to version '$oldver'.";
          }
        }
        print LOG "$tab$line\n";
      }
      print LOG "$indent----->cvs update : end output<-----\n";

      ## If the update didn't work, modify the status
      if ($status !~ /Success!/) {
        $status = "Problem!\n$tab-->File '$file' is missing and couldn't be restored to version '$oldver'.";
      }
    }

  } else {
    ## Ok, the file does exist; now restore the correct version.
  
    ## Check to make sure this host has the expected version
    $working = &CheckStatus("$host","$path","$file");
  
    ## If the old version exists, don't do anything else
    if ($working eq $oldver) {
      $status = "Success!\n$tab-->Version update not needed - old version '$working' exists.";
    } else {
  
      ## If old version was "NF", just delete it
      if ($oldver eq "NF") {
        chomp(@results = &DoDelete("$host","$path","$file"));
        print LOG "$indent----->rm : begin output<-----\n";
        foreach $line (@results) {
          print LOG "$tab$line\n";
        }
        print LOG "$tab Removing $path/$file from $host.\n";
        print LOG "$indent----->rm : end output<-----\n";
        $status = "Success!";
      } else {
        ## Do the update
        chomp(@results = &DoUpdate("$host","$path","$file","$oldver"));
  
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
      }
  
      ## If the status is not 'Success', a problem occurred with the update
      if ($status !~ /Success!/) {
        $status = "Problem!\n$tab-->'cvs update' returned an unexpected update code - '$code'.";
      } else {
  
        ## If old version was "NF", the repository will still 'see' it, so
        ## check the filesystem to make sure it is really gone
        if ($oldver eq "NF") {
          $exists = &CheckFile("$host","$path","$file");
  
          ## If the file still exists, the delete didn't work
          if ($exists) {
            $status  = "Problem!\n$tab-->Delete unsuccessful - new file '$file' still exists on '$host'.";
          } else {
            ## The file is gone now; just update this for output purposes
            $oldver = "deleted";
          }
        } else {
          ## Double check that the file was actually updated correctly
          $working = &CheckStatus("$host","$path","$file");
  
          ## If the versions don't match, update the status again
          if ($working ne $oldver) {
            $status = "Problem!\n$tab-->Incorrect version after update - Expecting '$oldver', Found '$working'.";
          }
        }
  
      } #end if status ne success
  
    } #end if working ne oldver

  } #end if exists

  ## Print the status of this file update
  &formattedPrint;
  &display("$status\n");

}

## Print the footer info
&display("*************************\n");
&display("* File Backout Complete *\n");
&display("*************************\n");

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
  my $fdiff = (length($file) < $flen ? $flen - length($file) : 1);
  my $string  = $indent;
     $string .= $host . $s x $hdiff . $s x 2;
     $string .= $oldver . $s x $odiff . $s x 2;
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
  &display("\nUsage: CMbackout.pl configfile username\n\n");
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
    chomp(@findings = `cvs status $thisfile 2>&1`);
    chdir($wkdir);
  } else {
    chomp(@findings = `ssh $user\@$thishost '. ./.cmprofile; date; hostname; cd $thispath; pwd; cvs status $thisfile 2>&1' 2>&1`);
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


#######################################################
## Use the 'ls' command to see if the file has been  ##
## deleted successfully.  If the host that we are    ##
## updating is the local host, ssh is not necessary. ##
## Return the result to the caller.                  ##
#######################################################
sub CheckFile {
  my $thishost = shift(@_);
  my $thispath = shift(@_);
  my $thisfile = shift(@_);
  my (@findings,$line);
  my $foundit = 0;

  ## If this host is the localhost, don't use ssh
  if ($thishost eq $localhost) {
    chdir($thispath);
    chomp(@findings = `ls -1 $thisfile 2>&1`);
    chdir($wkdir);
  } else {
    chomp(@findings = `ssh $user\@$thishost '. ./.cmprofile; date; hostname; cd $thispath; pwd; ls -1 $thisfile 2>&1' 2>&1`);
  }

  ## Scan the output to see if the file exists
  print LOG "$indent----->ls : begin output<-----\n";
  foreach $line (@findings) {
    if ($line =~ /^$thisfile$/) {
      $foundit = 1;
    }
    print LOG "$tab$line\n";
  }
  print LOG "$indent----->ls : end output<-----\n";

  return($foundit);
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
    chomp(@findings = `cvs update -r$thisver $thisfile 2>&1`);
    chdir($wkdir);
  } else {
    chomp(@findings = `ssh $user\@$thishost '. ./.cmprofile; date; hostname; cd $thispath; pwd; cvs update -r$thisver $thisfile 2>&1' 2>&1`);
  }

  return(@findings);
}


#########################################################
## Delete the given file from the filesystem, assuming ##
## that it was a new file so a previous version is not ##
## available.  If the host that we are updating is the ##
## local host, ssh is not necessary.                   ##
#########################################################
sub DoDelete {
  my $thishost = shift(@_);
  my $thispath = shift(@_);
  my $thisfile = shift(@_);
  my @findings;

  ## If this host is the localhost, don't use ssh
  if ($thishost eq $localhost) {
    chdir($thispath);
    system("rm $thisfile 2>&1");
    chdir($wkdir);
  } else {
    chomp(@findings = `ssh $user\@$thishost '. ./.cmprofile; date; hostname; cd $thispath; pwd; rm $thisfile 2>&1' 2>&1`);
  }

  return(@findings);
}
