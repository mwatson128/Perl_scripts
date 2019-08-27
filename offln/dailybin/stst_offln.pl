#!/bin/perl
#*TITLE - stst_offln.pl - Perl script to run daily offline processes - 1.4
#*SUBTTL Preface, and environment
#
#  (]$[) stst_offln.pl:1.4 | CDATE=00:10:11 19 Feb 1998
#
#
#       Copyright (C) 1998 THISCO, Inc.
#             All Rights Reserved
#
#
#  (source code is in /usw/src/scripts/offln/perl)

#*SUBTTL main - set up some variables necessary for internal execution
#
# main
#
# set global variables for the script
#
# parameters:
#   parameters are passed (untouched) to offln.pl
#
# globals (inherited):
#   %ENV	- Hash of environment variables.  The following keys are
#       	  added before executing the offln.pl script:
#
#     DBUG	- flag indicating whether or not to print to debug trace file
#     domain	- USW environment that the execution is for (QA, Prod, etc)
#     0    	- the name of this script.  used in e-mail so people know
#       	  what command to type in to restart this script.
#     localhost	- host name of machine script is to run on
#     rundir	- directory on $localhost script runs in
#     rbin	- test, QA, or production directory where executables reside
#     logfile	- the output log for the script (e.g. offln.log)
#     DL_offln	- e-mail distribution list for error_out() and warn_out()
#     DL_opsrpt	- e-mail list inherited by the OPS report, should it be called
#     DL_logxerr	- e-mail distribution sent to mail_out() should the
#            		  .err file from logx be larger than $logxerr_size
#     logxerr_size	- threshold size (in characters) for logx's .err file
#     database_a	- database name for primary reports
#     database_b	- database name for secondary reports
#     remotehost	- host name of machine, where log files reside
#     remotelogin	- login on $remotehost used to RCP files via
#     lgrpt_dir		- remote directory from which LGRPT files are retrieved
#     lgrpt_altdir	- remote directory LGRPT files are moved off to 
#                	  to prevent lgrpt_dir disk from getting too full
#     lgrej_dir		- remote directory from which LGREJ files are retrieved
#     lgper_dir		- remote directory from which LGPER files are retrieved
#     qcheck_dir	- remote directory from which QCHECK files are retrieved
#     arcdir_sum	- local directory into which LGRPT SUM files are stored
#     arcdir_vol	- local directory into which LGRPT VOL files are stored
#     arcdir_per	- local directory into which LGPER SUM files are stored
#     arcdir_logxerr	- local directory into which LOGX ERR files are stored
#     arcdir_logxerr	- local directory inwhich OPS Report is made
#
# globals (defined):
#   none
#
# locals (inherited/defined):
#   none
#
# mys:
#   rtn_val	- return value from offln.pl
#

{

  my($rtn_val);

  # clear all environment variables
  #
  #%ENV = ();

  # set environment variables
  #
  $ENV{PATH} = "/qa2/offln/bin:/qa/offln/rbin:/usr/bin:/usr/ucb:/bin:/usr/local/bin";
  $ENV{TBCONFIG} = "tbconfig.1";
  $ENV{INFORMIXDIR} = "/pdl/informix";
  $ENV{SQLEXEC} = "$ENV{INFORMIXDIR}/lib/sqlturbo";
  $ENV{ONCONFIG} = "onconfig.usw_test_1";
  $ENV{INFORMIXSERVER} = "usw_test_1";
  $ENV{DBDATE} = "mdy4/";

  # debug on/off
  #
  $ENV{DBUG} = 1;

  # execution location & logs
  #
  $ENV{domain} = "Stress_Test";
  $ENV{0} = $0;
  $ENV{localhost} = "usw_test";
  $ENV{rundir} = "/qa2/offln/daily";
  $ENV{rbin} = "/qa2/offln/rbin";
  $ENV{logfile} = "offln.log";

  # mail distribution lists
  #
  $runner = `whoami`; chomp($runner);
  @{TC} = ('@thisco.com');
  @ENV{DL_offln} = "$ENV{ST_mailrecipient}";
  @ENV{DL_logxerr} = "$ENV{ST_mailrecipient}";
  @ENV{DL_opsrpt} = "$ENV{ST_mailrecipient}";

  # execution parameters for reports
  #
  $ENV{database_a} = "testoffln";
  $ENV{database_b} = "testoffln";
  $ENV{logxerr_size} = "200000";
  
  # production name & file locations
  #
  $ENV{remotehost} = "usw_test"; 
  $ENV{remotelogin} = "${runner}"; 
  $ENV{lgrpt_dir} = "/qa2/lg";
  $ENV{lgrpt_altdir} = "/qa2/lg";
  $ENV{lgrej_dir} = "/qa2/lg";
  $ENV{lgper_dir} = "/qa2/lg";
  $ENV{qcheck_dir} = "/qa2/qdata";
  
  # archive directories for files & reports
  #
  $ENV{arcdir_sum} = "/dev/null";
  $ENV{arcdir_vol} = "/dev/null";
  $ENV{arcdir_per} = "/dev/null";
  $ENV{arcdir_logxerr} = "/qa2/offln/arch";
  $ENV{arcdir_opsrpt} = "/qa2/offln/arch";
  $ENV{opsrpt_format} = "html";

  # run the script 
  #
  $command = "$ENV{rbin}/offln.pl $ENV{ST_date} LGPER LGRPT SILENTOPS";
  if ($rtn_val = system ($command)) {
    print "$rtn_val from $0\n";
    exit(-1);
  }


  ##
  ## RCP the file over
  ##
  $xdated = `getydate -d 0 -t $ENV{ST_date}`;
  $filename = "$xdated.opsrpt";
  $command = "rcp $ENV{arcdir_opsrpt}/$filename $ENV{ST_remotelogin}\@$ENV{ST_remotehost}:$ENV{ST_remotedir}/$ENV{ST_remotefilename}  >>$ENV{rundir}/$ENV{logfile} 2>>$ENV{rundir}/$ENV{logfile}";

  if ($rtn_val = system ($command)) {
    system("elm -s 'rcp of p2perf report failed'  ${ST_mailrecipient} < $ENV{rundir}/$ENV{logfile} >> /dev/null 2>> /dev/null");
    exit(-2);
  }

}
