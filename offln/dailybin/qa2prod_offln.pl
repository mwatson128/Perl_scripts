#!/bin/perl
#*TITLE - qa2prod_offln.pl - Perl script to run daily offline processes - 1.3
#*SUBTTL Preface, and environment 
#
#  (]$[) qa2prod_offln.pl:1.3 | CDATE=20:32:39 08 Dec 1997
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
  $ENV{PATH} = "/qa2/offln/bin:/qa/offln/rbin:/usr/bin:/usr/ucb:/bin:/usr/local/bin";
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
  $ENV{domain} = "QA2_Prod";
  $ENV{0} = $0;
  $ENV{localhost} = "usw_test";
  $ENV{rundir} = "/qa2/offln/daily";
  $ENV{rbin} = "/qa/offln/rbin";
  $ENV{logfile} = "offln.log";

  # mail distribution lists
  #
  $runner = `whoami`; chomp($runner);
  @{TC} = ('@thisco.com');
  @ENV{DL_offln} = "${runner}@{TC}";
  @ENV{DL_logxerr} = "${runner}@{TC}";
  @ENV{DL_opsrpt} = "tedl@{TC} davidj@{TC} gregh@{TC} davidw@{TC}";

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
  $ENV{lgper_dir} = "/offln/daily";
  $ENV{qcheck_dir} = "/qa2/qdata";
  
  # archive directories for files & reports
  #
  $ENV{arcdir_sum} = "/dev/null";
  $ENV{arcdir_vol} = "/dev/null";
  $ENV{arcdir_per} = "/dev/null";
  $ENV{arcdir_logxerr} = "/qa2/offln/arch";
  $ENV{arcdir_opsrpt} = "/qa2/offln/arch";
  

  ##
  ##  magic stuff
  ##
    if(0 == $ARGC) {
      $date = `getydate -s`;
    }
    elsif(1 == $ARGC) {
      $date = shift(@ARGV);
    }
    else {
      fprintf(STDERR, "\nusage: $0 [date]\n\n");
    }
    

  # clean out the  database (for space reasons)
  #
  if ( $rtn_val = system ("expire -d $ENV{database_b} -n p2perf -t ${date}")) {
    print "$rtn_val from $0 in database clear\n";
  }

  # run the script 
  #
  if ( $rtn_val = system ("$ENV{rbin}/offln.pl $date LGPER", @ARGV)) {
    print "$rtn_val from $0 from offline \n";
  }
}
