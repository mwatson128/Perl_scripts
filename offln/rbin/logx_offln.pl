#!/bin/perl
#*TITLE - prod_offln.pl - Perl script to run daily offline processes - 1.22
#*SUBTTL Preface, and environment 
#
#  (]$[) prod_offln.pl:1.22 | CDATE=14:36:52 22 Jul 1998
#
#
#	Copyright (C) 1996 THISCO, Inc.
#	      All Rights Reserved
#
#

# includes
require "/usw/offln/stdperl";

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

  # set environment variables
  #
  setenv("PATH", ".:/usw/offln/bin:/usw/offln/rbin:/usr/bin:/usr/ucb:/bin:/usr/local/bin", 1);
  setenv("TBCONFIG", "tbconfig.1", 1);

  # execution location & logs
  #
  setenv("domain", "logx verification ");
  setenv("0", $0);
  setenv("localhost", "usw_test");
  setenv("rundir", "/usw/offln/verify");
  setenv("rbin", "/usw/offln/rbin");
  setenv("logfile", "offln.log");

  # mail distribution lists
  #
  setenv("DL_offln", "$DL_{DL_TEST} tedl\@pegsinc.com");
  setenv("DL_logxerr", "$DL_{DL_TEST}");
  setenv("DL_opsrpt", "$DL_{DL_TEST}");

  setenv("logxerr_size", "400000");
  
  # production name & file locations
  #
  setenv("remotehost", "usw_test"); 
  setenv("remotelogin", "uswrpt"); 
  setenv("lgrpt_dir", "/loghist/co");
  setenv("lgrpt_altdir", "/loghist/rpt");
  setenv("lgrej_dir", "/loghist/rej");
  setenv("lgper_dir", "/loghist/per");
  setenv("qcheck_dir", "/prod/perf/qdata");
  
  # archive directories for files & reports
  #
  setenv("arcdir_logxerr", "/usw/reports/daily/logx_errx");
  setenv("arcdir_sum", "/usw/reports/daily/sumx");
  setenv("arcdir_vol", "/usw/reports/daily/volx");
  
  # run the script 
  #
  if ( $rtn_val = system ("$ENV{rbin}/offln.pl", @ARGV)) {
    print "$rtn_val from $0\n";
  }
}
