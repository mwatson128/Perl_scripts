#!/bin/perl
#*TITLE - %M% - Perl script to run daily offline processes - %I%
#*SUBTTL Preface, and environment 
#
#  (]$[) %M%:%I% | CDATE=%U% %G%
#
#
#	Copyright (C) 1996 THISCO, Inc.
#	      All Rights Reserved
#
#

#*SUBTTL lgrpt_vtally - run db tally LGRPT message volume information
#
# lgrpt_vtally()
#
# tally the LGRPT message volume information using DVOLTAL---first purging
# any data that lay in the target table (DVOL_TBL) for the period to be run.
#
# parameters:
#   none
#
# globals:
#
# locals 
#   inherited:
#     rtn_val	- return value to main; modifiable by all sub's called
#
#   defined:
#     none
# 
# mys:
#   none
#
# returns:
#   rtn_val	- return value from subroutines and commands
#

sub lgrpt_vtally 
{
  LOGENTER("LGRPT: VTALLY");

  # test for volume file
  unless (-e ${lgrptvol_file}) {
    print(LOGFILE "File not present, getting it from the archive directory\n");
    system("gzcat ${arcdir_vol}/${lgrptvol_file}.gz > ./${lgrptvol_file}");
  }

  # see if LGRPT-VOL file is in 'execute directory'
  # if not check in the archive directory, and uncompress it
  # write a function that does this for all tally programs

  # purge information from vol_tbl
  print(LOGFILE "start of PURGE of DVOL_TBL for ${date}: ", `date`);
  $db_command = "purge -d ${database_a} -t ${date} -n dvol_tbl -f ddate";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEVOLTBL, $rtn_val);
    return($rtn_val);
  }

  # tally LGRPT-VOL volume information
  print(LOGFILE "start of DVOLTAL for ${lgrptvol_file}: ", `date`);
  $db_command = "dvoltal -d ${database_a} -l ${lgrptvol_file}"; 
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_VTALLY, $rtn_val);
    return($rtn_val);
  }
  print(LOGFILE "end of VTALLY for ${lgrptvol_file}: ", `date`);

  # delete LGRPT VOL file, if it's safe to do so
  if (-e "ARC.${lgrptvol_file}.notarc") {
    print LOGFILE "CANNOT REMOVE: archive of ${lgrptvol_file} failed.\n";
  }
  elsif ($procs{$arg}{'mf'}) {
    print LOGFILE "Waiting To Remove ${lgrptvol_file}.\n";
  }
  else {
    system("rm -f  ${lgrptvol_file}");
  }

  LOGEXIT("LGRPT: VTALLY");

  return($rtn_val);
}

#*SUBTTL lgrpt_dtally - run db tally of LGRPT billing information
#
# lgrpt_dtally()
#
# tally the LGRPT message billing information (by hour) using DTALLY---
# first purging any data that lay in the target table (HOUR_TBL) for 
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

sub lgrpt_dtally 
{
  LOGENTER("LGRPT: DTALLY");

  # test for summary file
  unless (-e ${lgrptsum_file}) {
    print(LOGFILE "File not present, getting it from the archive directory\n");
    system("gzcat ${arcdir_sum}/${lgrptsum_file}.gz > ./${lgrptsum_file}");
  }

  # see if LGRPT-SUM file is in 'execute directory'
  # if not check in the archive directory, and uncompress it
  # write a function that does this for all tally programs

  # arrive at historical date to expire at
  my($edate) = `getydate -d '-90' -s`;

  # expire information from hour_tbl
  print(LOGFILE "start of EXPIRE of HOUR_TBL for ${edate}: ", `date`);
  $db_command = "expire -d ${database_a} -t ${edate} -n hour_tbl";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_EXPIREHOURTBL, $rtn_val);
    return($rtn_val);
  }

  # purge information from hour_tbl
  print(LOGFILE "start of PURGE of HOUR_TBL for ${date}: ", `date`);
  $db_command = "purge -d ${database_a} -t ${date} -n hour_tbl -f ddate";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEHOURTBL, $rtn_val);
    return($rtn_val);
  }

  chdir ${rundir};
  # run DTALLY & write the data out to an intermediate file
  print(LOGFILE "start of DTALLY tally/write for ${lgrptsum_file}: ", `date`);
  print(LOGFILE " dtally is ", `type dtally`);
  $db_command = "dtally -d ${database_a} -t ${date} -W ${dtally_interfile} ";
  print(LOGFILE " command is -", $db_command, "-\n");
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {
    # there was an error.  call error handler and exit
    error_out($E_DTALLY, $rtn_val);
    return($rtn_val);
  }

  # use DTALLY to read the data from the intermediate file & load the database
  print(LOGFILE "start of DTALLY for read/load for ${lgrptsum_file}: ", `date`);
  $db_command = "dtally -d ${database_a} -t ${date} -R ${dtally_interfile}";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_DTALLY, $rtn_val);
    return($rtn_val);
  }

  # we're through with the intermediate file
  system("rm -f ${dtally_interfile}");

  # run MTALLY
  !($rtn_val = &lgrpt_mtally) || return($rtn_val);

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

  LOGEXIT("LGRPT: DTALLY");
  return($rtn_val);
}

#*SUBTTL lgrpt_mtally - run db tally of LGRPT billing information
#
# lgrpt_mtally()
#
# tally the LGRPT billing information (by day) using MTALLY---first 
# purging any data that lay in the target table (DAY_TBL) for the 
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

sub lgrpt_mtally 
{
  LOGENTER("LGRPT: MTALLY");

  # purge information from day_tbl
  print(LOGFILE "start of PURGE of DAY_TBL for ${date}: ", `date`);
  $db_command = "purge -d ${database_a} -t ${date} -n day_tbl -f ddate";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEDAYTBL, $rtn_val);
    return($rtn_val);
  }

  # tally LGRPT-SUM billing information (by day)
  print(LOGFILE "start of MTALLY for ${date}: ", `date`);
  $db_command = "mtally -d ${database_a} -t ${date}";
  if ($rtn_val = system("$db_command >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_MTALLY, $rtn_val);
    return($rtn_val);
  }
  print(LOGFILE "end of MTALLY for ${lgrptsum_file}: ", `date`);
  print(LOGFILE "end time of LGRPT-SUM-BILLING thread is ", `date`, ".\n");

  # touch file for last date of completed billing
  my($billthru) = "${ndate}.billing";
  my($billthruprev) = `ls [0-9][0-9][0-1][0-9][0-3][0-9].billing 2>>/dev/null`;
  if (${billthru} gt ${billthruprev}) {
    system("rm -f ${billthruprev} 2>>/dev/null");
    system("touch ${billthru}");
  }
  $DBUG && print DJUNK "\nBILL: ${billthru};  PBILL: ${billthruprev}\n";

  LOGEXIT("LGRPT: MTALLY");

  return($rtn_val);
}

1;

#*SUBTTL structures for error_out and warning_out mailings:  lgrpt_vtally
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


$E_VTALLYNOTOK = { 
  'subject', "LGRPT thread failed", 
  'rs_here', "VTALLY", 
  'mf', "DTALLY PTALLY", 
  'rs_higher_f', 1, 
  'rs_higher', "LGRPT_DB", 
'body', "the VTALLY.notok file was in existance when this thread tried to run

Another DVOLTAL could currently be running.  Check to be sure
that there isn't.  If another is running, wait for it to complete before
restarting.

Or a previous DVOLTAL could have failed.  Check the ${logfile} and 
past mailings to determine if this is the case.  If so, see that the 
failed process is restarted.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_PURGEVOLTBL = {
  'subject', "LGRPT's purge of the VOL_TBL table failed", 
  'rs_here', "VTALLY", 
  'mf', "DTALLY PTALLY", 
  'rs_higher_f', 1, 
  'rs_higher', "LGRPT_DB", 
'body', "the purge of the KSFSIZE table for ${date} (in ${database_a}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone in the morning.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_VTALLY = {
  'subject', "LGRPT's DVOLTAL failed", 
  'rs_here', "VTALLY", 
  'mf', "DTALLY PTALLY", 
  'rs_higher_f', 1, 
  'rs_higher', "LGRPT_DB", 
'body', 
"the VTALLY program failed to load data from ${lgrptvol_file} into the database

Check the ${logfile} to see what the problem was.  Double check to make sure 
no other programs were trying to access this table at the same time, then 
restart.  

If the trouble cannot be fixed, inform someone immediately using the 
on-call escalation procedures

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

#*SUBTTL structures for error_out and warning_out mailings:  lgrpt_dtally
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


$E_DTALLYNOTOK = { 
  'subject', "LGRPT thread failed", 
  'rs_here', "DTALLY", 
  'mf', "PTALLY", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the DTALLY.notok file was in existance when this thread tried to run

Another DTALLY could currently be running.  Check to be sure
that there isn't.  If another is running, wait for it to complete before
restarting.

Or a previous DTALLY could have failed.  Check the ${logfile} and 
past mailings to determine if this is the case.  If so, see that the 
failed process is restarted.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_EXPIREHOURTBL = {
  'subject', "LGRPT's expire of the HOUR_TBL table failed", 
  'rs_here', "DTALLY", 
  'mf', "PTALLY", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the expire of the HOUR_TBL table for ${date} (in ${database_a}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_PURGEHOURTBL = {
  'subject', "LGRPT's purge of the HOUR_TBL table failed", 
  'mf', "PTALLY", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the purge of the HOUR_TBL table for ${date} (in ${database_a}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_DTALLY = {
  'subject', "LGRPT's DTALLY failed", 
  'rs_here', "DTALLY", 
  'mf', "", 
  'rs_higher_f', 1, 
  'rs_higher', "LGRPT_DB", 
'body', 
"the DTALLY program failed to load data from ${lgrptsum_file} into the database

Check the ${logfile} to see what the problem was.  Double check to make sure 
no other programs were trying to access this table at the same time, then 
restart.  

If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

#*SUBTTL structures for error_out and warning_out mailings:  lgrpt_mtally
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


$E_MTALLYNOTOK = { 
  'subject', "LGRPT thread failed", 
  'rs_here', "MTALLY", 
  'mf', "", 
  'rs_higher_f', 1, 
  'rs_higher', "LGRPT_DB", 
'body', "the MTALLY.notok file was in existance when this thread tried to run

Another MTALLY could currently be running.  Check to be sure
that there isn't.  If another is running, wait for it to complete before
restarting.

Or a previous MTALLY could have failed.  Check the ${logfile} and 
past mailings to determine if this is the case.  If so, see that the 
failed process is restarted.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_PURGEDAYTBL = {
  'subject', "LGRPT's purge of the DAY_TBL table failed", 
  'rs_here', "MTALLY", 
  'mf', "PTALLY", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the purge of the DAY_TBL table for ${date} (in ${database_a}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_MTALLY = {
  'subject', "LGRPT's MTALLY failed", 
  'rs_here', "MTALLY", 
  'mf', "", 
  'rs_higher_f', 1, 
  'rs_higher', "LGRPT_DB", 
'body', 
"the MTALLY program failed to load data from ${lgrptsum_file} into the database

Check the ${logfile} to see what the problem was.  Double check to make sure 
no other programs were trying to access this table at the same time, then 
restart.  

If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

1;
