#!/bin/perl
#*TITLE - rerun_offln.pl - Perl script to run daily offline processes - 1.2
#*SUBTTL Preface, and environment 
#
#  (]$[) rerun_offln.pl:1.2 | CDATE=16:10:10 03 Jul 1997
#
#
#	Copyright (C) 1996 THISCO, Inc.
#	      All Rights Reserved
#
#

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
  %ENV = ();

  # set environment variables
  #
  $ENV{PATH} = "/usw/offln/bin:/usw/offln/rbin:/usr/bin:/usr/ucb:/bin:/usr/local/bin";
  $ENV{TBCONFIG} = "tbconfig.1";
  $ENV{INFORMIXDIR} = "/pdl/informix";
  $ENV{SQLEXEC} = "$ENV{INFORMIXDIR}/lib/sqlturbo";
  $ENV{ONCONFIG} = "onconfig.usw_test_1";
  $ENV{INFORMIXSERVER} = "usw_test_1";
  $ENV{DBDATE} = "mdy4/";

  # debug on/off
  #
  $ENV{DBUG} = 0;

  # execution location & logs
  #
  $ENV{domain} = "Prod";
  $ENV{0} = $0;
  $ENV{localhost} = "usw_test";
  $ENV{rundir} = "/offln/rerun";
  $ENV{rbin} = "/usw/offln/rbin";
  $ENV{logfile} = "offln.log";

  # mail distribution lists
  #
  @{TC} = ('@thisco.com');
  @ENV{DL_offln} = "davidw@{TC}";
  @ENV{DL_logxerr} = "davidw@{TC}";
  @ENV{DL_opsrpt} = "davidw@{TC}";

  # execution parameters for reports
  #
  $ENV{database_a} = "uswoffln";
  $ENV{database_b} = "usw_perf";
  $ENV{logxerr_size} = "400000";
  
  # production name & file locations
  #
  $ENV{remotehost} = "usw_prod"; 
  $ENV{remotelogin} = "prod_sup"; 
  $ENV{lgrpt_dir} = "/prod/m3/usw/lg";
  $ENV{lgrpt_altdir} = "/prod/m4/loghist";
  $ENV{lgrej_dir} = "/prod/m3/usw/lg";
  $ENV{lgper_dir} = "/prod/m3/usw/lg2";
  $ENV{qcheck_dir} = "/prod/m2/usw/perf/qdata";
  
  # archive directories for files & reports
  #
  $ENV{arcdir_sum} = "/reports/daily/sum";
  $ENV{arcdir_vol} = "/reports/daily/vol";
  $ENV{arcdir_per} = "/reports/daily/per";
  $ENV{arcdir_logxerr} = "/reports/daily/logx_err";
  $ENV{arcdir_opsrpt} = "/reports/daily/opsrpt";
  
  # run the script 
  #
  if ( $rtn_val = system ("$ENV{rbin}/offln.pl", @ARGV)) {
    print "$rtn_val from $0\n";
  }
}
