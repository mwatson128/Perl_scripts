#!/opt/dba/perl5.8.4/bin/perl

#******************************************************************************#
#*                          Wells Fargo Mortgage                              *#
#*                    SMS - Secondary Marketing System                        *#
#******************************************************************************#
#*  Program Name:  checkcust.pl                                               *#
#*                                                                            *#
#*  Description:  This program will look in the database to check if the user *#
#*                has accessed certain stored procedures, the update_config_sp*#
#*                is the stored procedure that populates the database and     *#
#*                this script checks the records                              *#
#*                                                                            *#
#*  Tables Accessed : sms_config                                              *#
#*                    no updates to the table but depends on TIGSTAFF         *#
#*                    the user name of the stored procedure                   *#
#*                                                                            *#
#*  Parameters:                                                               *#
#*               User ID        ASCII String      User name to look for       *#
#******************************************************************************#
#*  Change History                                                            *#
#*                                                                            *#
#*  Chg  Rel   Programmer      Date       Description                         *#
#*  ---  ---   ----------      ----       ---------------------------         *#
#*  0    1.0   Bruce Fausey   02/09/07   Original Delivery                    *#
#******************************************************************************#

# Required Perl modules

use strict;
use Sybase::DBlib;
use File::stat;
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);

# Global variables used in this script

# strings
my $dbs='';
my $user='';
my $filename='';
my $cmd='';

# integers
my $yes_mail=0;
my $fdow=0;

# hash tables
my %WEEK_DAYS=();
my %HOLIDAYS={};

# arrays
my @today_date=();
my @mailgrp=();
my @dte_find=();
my @row=();

# Open the database

$dbs = new Sybase::DBlib $ENV{SMSID}, $ENV{SMSPWD}, $ENV{OPR_DSQUERY} || 
     die "connection to $ENV{OPR_DSQUERY} failed $!\n";

# Setup the days of week this is based on the Day_of_Week function
# Monday being the first and Sunday being seven

$WEEK_DAYS{MONDAY}=1;
$WEEK_DAYS{TUESDAY}=2;
$WEEK_DAYS{WEDNESDAY}=3;
$WEEK_DAYS{THURSDAY}=4;
$WEEK_DAYS{FRIDAY}=5;
$WEEK_DAYS{SATURDAY}=6;
$WEEK_DAYS{SUNDAY}=7;

# We need todays date
(@today_date) = Today(); 

# get major HOLIDAYS for check

# New Years Day
$HOLIDAYS{sprintf("%04d%02d%02d",@today_date[0],1,1)} = 1;

# Memorial Day
# start at end of month and subtract days until the date is last Monday
(@dte_find) = (@today_date[0],5,31);
do {
      $fdow = Day_of_Week(@dte_find);
      if ($fdow != $WEEK_DAYS{MONDAY}) {
        @dte_find = Add_Delta_Days(@dte_find,-1);    
      }
} until ($fdow == $WEEK_DAYS{MONDAY});
$HOLIDAYS{sprintf("%04d%02d%02d",@dte_find[0],@dte_find[1],@dte_find[2])} = 1;

# Indenpendance Day 
$HOLIDAYS{sprintf("%04d%02d%02d",@today_date[0],7,4)} = 1;

# Labor Day
# Start with the first day of September and work forward until first Monday
(@dte_find) = (@today_date[0],9,1);
do {
      $fdow = Day_of_Week(@dte_find);
      if ($fdow != $WEEK_DAYS{MONDAY}) {
        @dte_find = Add_Delta_Days(@dte_find,1);    
      }
} until ($fdow == $WEEK_DAYS{MONDAY});
$HOLIDAYS{sprintf("%04d%02d%02d",@dte_find[0],@dte_find[1],@dte_find[2])} = 1;

# Thanksgiving Day
# Start with the first and look for the first Thursday
(@dte_find) = (@today_date[0],11,1);
do {
      $fdow = Day_of_Week(@dte_find);
      if ($fdow != $WEEK_DAYS{THURSDAY}) {
        @dte_find = Add_Delta_Days(@dte_find,1);    
      }
} until ($fdow == $WEEK_DAYS{THURSDAY});

# now that we got the first Thursday add 3 weeks
@dte_find = Add_Delta_Days(@dte_find,21);    
$HOLIDAYS{sprintf("%04d%02d%02d",@dte_find[0],@dte_find[1],@dte_find[2])} = 1;

# Christmas
$HOLIDAYS{sprintf("%04d%02d%02d",@today_date[0],12,25)}=1;

# Build a temporary file to write the e-mail messages to
# one this file opens it will overwrite the file that is 
# in the /tmp directory if the directory is cleaned out
# we will create a new one.

$filename = "/tmp/cust_check.txt";

open(MAILMSG,">$filename") || die "could not write $filename $! \n";

# Do the query to the database -- Main processing loop

$dbs->dbcmd("select cnfg_parm_txt, cnfg_parm_nme  from sms.dbo.sms_config where cnfg_parm_txt like 'dal_up%'");
$dbs->dbsqlexec;
if ($dbs->dbresults == 1) {

  while (@row = $dbs->dbnextrow) {
    # Split the line at the colon into stored procedure name and last date used
 
    (my $proc, my $last_date) = split(":",@row[0]);

    # The easy way is to unpack the date and put it into an array for the Date::Calc to use

    my @db_date = (unpack("a4",$last_date),unpack("x4 a2",$last_date),unpack("x6 a2",$last_date));    

    # Since perl has no switch function, the following is the if statements used  
    # Use the date calculate function to see how may days between today and the
    # date the stored procedure was last used

    my $day_diff = Delta_Days(@db_date,@today_date);
    # Was the procedure more than three days ago 
    if ($day_diff > 3) {
      $yes_mail = 1;
    # Was the procedure run today
    } elsif ($day_diff == 0 ) {
      $yes_mail = 0;
  
    # The timming could be a factor so don't worry about yesterday
    } elsif ($day_diff == 1) {
      $yes_mail = 0;

    # The date between could have been a Saturday so check that
    # and the timming could be a factor so don't worry about yesterday
    } elsif ($day_diff == 2 || $day_diff == 3) {

      # Just add one day to the date in the database and find out what day it was
      my @next_day = Add_Delta_Days(@db_date,1);    
      my $ldow = Day_of_Week(@next_day);
      if ($ldow == $WEEK_DAYS{SATURDAY}) {
        $yes_mail = 0;
      } else {
        # it may have been a holiday
        $last_date = sprintf("%04d%02d%02d",@next_day[0],@next_day[1],@next_day[2]);
        if (exists $HOLIDAYS{$last_date}) {
          $yes_mail = 0;
        } else {
          $yes_mail = 1;
        }
      }
    } 
    # If there was a message to be mailed write the message to the file
    if ($yes_mail) {
      print MAILMSG sprintf("Arrow/TIBCO failed to update the SMS database since %02d/%02d/%04d",@db_date[1],@db_date[2],@db_date[0]);
      print MAILMSG sprintf(" via the %s stored procedure %s. Contact the TIBCO on call to determine",$proc);
      print MAILMSG sprintf(" if a TIBCO failure occurred.\n");
      print MAILMSG "\n\n";
    }
  }
}

# Close the message file and if there was anything wrote to the file then we have
# process the file

close(MAILMSG);
if (stat("$filename")->size) {

  # To get the list of people who should know about non use of the procedures
  # there is a list of names in the database under TIGSTAFF it is the names
  # only seperated by a comma I will assume domain will always be wellsfargo.com
  $dbs->dbcmd("select cnfg_parm_txt from sms.dbo.sms_config where cnfg_parm_nme like 'TIGSTAF%'");
  $dbs->dbsqlexec;
  if ($dbs->dbresults == 1) {
    while (@row = $dbs->dbnextrow) {
      (my @names) = split(",",@row[0]);
      foreach my $nme (@names) {
        push(@mailgrp,sprintf("%s\@wellsfargo.com",$nme));
      }
    }
  }

  # Build the command to send the file to the group and process the command via the 
  # system function

  $cmd = sprintf("/bin/mailx -s'No update from Arrow/TIBCO' %s <%s",join(",",@mailgrp),$filename);
  system($cmd);
}

# Close the database and exit

$dbs->dbclose;
exit;
