#!/bin/perl
#*TITLE - %M% - Perl script to run daily offline processes - %I%
#*SUBTTL Preface, and environment 
#
#  (]$[) %M%:%I% | CDATE=%U% %G%
#
#	Copyright (C) 1996 THISCO, Inc.
#	      All Rights Reserved
#
#


#*SUBTTL lgrpt_ptally - run db tally of LGRPT billing information
#
# lgrpt_ptally()
#
# tally the LGRPT message performance information using PTALLY---
# first purging any data that lay in the target tables (APERF & BPERF) for 
# the period to be run.
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val	- return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub lgrpt_ptally 
{
  LOGENTER("LGRPT: PTALLY");

  # test for summary file
  unless (-e ${lgrptsum_file}) {
    print(LOGFILE "File not present, getting it from the archive directory\n");
    system("ln -s ${arcdir_sum}/${lgrptsum_file}.Z .");
    system("uncompress ${lgrptsum_file}");
  }

  # see if LGRPT-SUM file is in 'execute directory'
  # if not check in the archive directory, and uncompress it
  # write a function that does this for all tally programs

  # arrive at date for expiration of aperf info
  my($edate) = `getydate -t ${date} -d '-65' -s`;

  # expire information from aperf
  print(LOGFILE "start of EXPIRE of APERF for ${edate}: ", `date`);
  $db_command = "expire -d ${database_b} -t ${edate} -n aperf -f fromars ";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_EXPIREAPERF, $rtn_val);
    return($rtn_val);
  }

  # arrive at date for expiration of bperf info
  my($edate) = `getydate -t ${date} -d '-65' -s`;

  # expire information from bperf
  print(LOGFILE "start of EXPIRE of BPERF for ${edate}: ", `date`);
  $db_command = "expire -d ${database_b} -t ${edate} -n bperf -f from ";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_EXPIREBPERF, $rtn_val);
    return($rtn_val);
  }

  # purge information from aperf
  print(LOGFILE "start of PURGE of APERF for ${date}: ", `date`);
  $db_command = "purge -d ${database_b} -t ${date} -n aperf -f fromars ";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEAPERF, $rtn_val);
    return($rtn_val);
  }

  # purge information from bperf
  print(LOGFILE "start of PURGE of BPERF for ${date}: ", `date`);
  $db_command = "purge -d ${database_b} -t ${date} -n bperf -f from ";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEBPERF, $rtn_val);
    return($rtn_val);
  }

  # tally LGRPT-SUM performance information
  print(LOGFILE "start of PTALLY for ${lgrptsum_file}: ", `date`);
  $db_command = "ptally -d ${database_b} -l ${lgrptsum_file} ";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PTALLY, $rtn_val);
    return($rtn_val);
  }

  # run OPTALLY
  !($rtn_val = &lgrpt_optally) || return($rtn_val);

  # delete LGRPT SUM file, if it's safe to do so
  if (-e "ARC.${lgrptsum_file}.notarc") {
    print LOGFILE "CANNOT REMOVE: archive of ${lgrptsum_file} failed.\n";
  }
  elsif ($procs{$arg}{'mf'}) {
    print LOGFILE "Waiting To Remove ${lgrptsum_file}.\n";
  }
  else {
    system("rm -f  ${lgrptsum_file}");
  }

  LOGEXIT("LGRPT: PTALLY");
  return($rtn_val);
}

#*SUBTTL lgrpt_optally - run db optimization of LGRPT performance information
#
# lgrpt_optally()
#
# tally the LGRPT performance information (by hour) using OPTALLY---first 
# purging any data that lay in the target table (BPERF) for the 
# period to be run.
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val	- return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub lgrpt_optally 
{
  LOGENTER("LGRPT: OPTALLY");

  # purge information from boperf
  print(LOGFILE "start of PURGE of BOPERF for ${date}: ", `date`);
  $db_command = "purge -d ${database_b} -t ${date} -n boperf -f ddate ";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEBOPERF, $rtn_val);
    return($rtn_val);
  }

  # tally LGRPT-SUM billing information (by day)
  print(LOGFILE "start of OPTALLY for ${date}: ", `date`);
  $db_command = "optally -d ${database_b} -t ${date} ";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_OPTALLY, $rtn_val);
    return($rtn_val);
  }
  print(LOGFILE "end of OPTALLY for ${lgrptvol_file}: ", `date`);
  print(LOGFILE "end time of LGRPT-SUM-PERFORMANCE thread is ", `date`, ".\n");

  LOGEXIT("LGRPT: OPTALLY");

  return($rtn_val);
}

1;


#*SUBTTL structures for error_out and warning_out mailings:  lgrpt_ptally
#
# variables are refernces to a hash with the following keys:
#   subject	- phrase to go into the subject of the mail message
#   rs_here	- (restart here) the command-line option needed to 
#                 start offln.pl 
#   mf	- (missed fork) the command-line option of any subthreads that
#	  might be missed should you start at 'rs_here'.  Whether this
#  	  option is included in the restart command mailed to the
#  	  operators depends upon if the original command line option
#    	  (for the run of offln.pl that produced this mail) would have
#  	  executed the subthreads.  A flag indicating this is in offln.pl 
#  	  in the hash %procs, under the key (of the same name) 'mf'.
#   rs_higher	- (restart higher) oftentimes if the particular thread
#         	  that errored-out, errored-out during the first function
#         	  of its first subthread, it would be more effecient to 
#       	  restart the thread than to use the 'rs_here' option, 
#        	  followed by the 'mf' option(s).  This is the command-line
#        	  option that would restart the thread.
#   body	- this is the body of the mail message.  In it should be 
#    		  a description of the problem, possible reasons for it's 
#       	  occurrence, potential solutions for the problem, and 
#        	  what the operator needs to do to restart the script.
#


$E_PTALLYNOTOK = { 
  'subject', "LGRPT thread failed", 
  'rs_here', "PTALLY", 
  'mf', "", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the PTALLY.notok file was in existance when this thread tried to run

Another PTALLY could currently be running.  Check to be sure
that there isn't.  If another is running, wait for it to complete before
restarting.

Or a previous PTALLY could have failed.  Check the ${logfile} and 
past mailings to determine if this is the case.  If so, see that the 
failed process is restarted.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

$E_EXPIREAPERF = {
  'subject', "LGRPT's expire of the APERF table failed", 
  'rs_here', "PTALLY", 
  'mf', "", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the expire of the APERF table for ${date} (in ${database_a}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

$E_EXPIREBPERF = {
  'subject', "LGRPT's expire of the BPERF table failed", 
  'rs_here', "PTALLY", 
  'mf', "", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the expire of the BPERF table for ${date} (in ${database_b}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_PURGEAPERF = {
  'subject', "LGRPT's purge of the APERF table failed", 
  'rs_here', "PTALLY", 
  'mf', "", 
  'rs_higher_f', 1, 
  'rs_higher', "LGRPT_DB", 
'body', "the purge of the APERF table for ${date} (in ${database_b}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_PURGEBPERF = {
  'subject', "LGRPT's purge of the BPERF table failed", 
  'rs_here', "PTALLY", 
  'mf', "", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the purge of the BPERF table for ${date} (in ${database_b}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_PTALLY = {
  'subject', "LGRPT's PTALLY failed", 
  'rs_here', "PTALLY", 
  'mf', "", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', 
"the PTALLY program failed to load data from ${lgrptsum_file} into the database

Check the ${logfile} to see what the problem was.  Double check to make sure 
no other programs were trying to access this table at the same time, then 
restart.  

If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

#*SUBTTL structures for error_out and warning_out mailings:  lgrpt_optally
#
# variables are refernces to a hash with the following keys:
#   subject	- phrase to go into the subject of the mail message
#   rs_here	- (restart here) the command-line option needed to 
#                 start offln.pl 
#   mf	- (missed fork) the command-line option of any subthreads that
#	  might be missed should you start at 'rs_here'.  Whether this
#  	  option is included in the restart command mailed to the
#  	  operators depends upon if the original command line option
#    	  (for the run of offln.pl that produced this mail) would have
#  	  executed the subthreads.  A flag indicating this is in offln.pl 
#  	  in the hash %procs, under the key (of the same name) 'mf'.
#   rs_higher	- (restart higher) oftentimes if the particular thread
#         	  that errored-out, errored-out during the first function
#         	  of its first subthread, it would be more effecient to 
#       	  restart the thread than to use the 'rs_here' option, 
#        	  followed by the 'mf' option(s).  This is the command-line
#        	  option that would restart the thread.
#   body	- this is the body of the mail message.  In it should be 
#    		  a description of the problem, possible reasons for it's 
#       	  occurrence, potential solutions for the problem, and 
#        	  what the operator needs to do to restart the script.
#


$E_PURGEBOPERF = {
  'subject', "LGRPT's purge of the BOPERF table failed", 
  'rs_here', "OPTALLY", 
  'mf', "", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the purge of the BOPERF table for ${date} (in ${database_b}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_OPTALLY = {
  'subject', "LGRPT's OPTALLY failed", 
  'rs_here', "OPTALLY", 
  'mf', "", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', 
"the OPTALLY program failed to load data from ${lgrptsum_file} into the database

Check the ${logfile} to see what the problem was.  Double check to make sure 
no other programs were trying to access this table at the same time, then 
restart.  

If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

1;
