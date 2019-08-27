#!/bin/perl
#*TITLE - prod_offln.pl - Perl script to run daily offline processes - 1.10
#*SUBTTL Preface, and environment 
#
#  (]$[) prod_offln.pl:1.10 | CDATE=15:05:11 01/17/08
#
#
#	Copyright (C) 1997-2006 Pegasus Systems, Inc.
#	      All Rights Reserved
#
#
$zone = `uname -n`;
chomp $zone;
$zone_informixserver = $zone . "_1";
$zone_informixdir = "/informix-" . $zone . "_1";

# includes
require "/$zone/usw/offln/stdperl";

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
  setenv("PATH", "/$zone/usw/offln/bin:/$zone/usw/offln/rbin:/usr/bin:/usr/ucb:/bin:/usr/local/bin", 1);
  setenv("TBCONFIG", "tbconfig.1", 1);
  setenv("INFORMIXSERVER", "$zone_informixserver", 1);
  setenv("INFORMIXDIR", "$zone_informixdir", 1);
  setenv("LD_LIBRARY_PATH", "$zone_informixdir/lib:$zone_informixdir/lib/esql", 1);
  setenv("SQLEXEC", "$zone_informixdir/lib/sqlturbo", 1);
  setenv("ONCONFIG", "onconfig.$zone_informixserver", 1);
  setenv("DBDATE", "mdy4/", 1);

  # debug on/off
  #
  setenv("DBUG", 0);

  # execution location & logs
  #
  setenv("domain", "Prod");
  setenv("0", $0);
  setenv("localhost", "$zone");
  setenv("rundir", "/$zone/usw/offln/daily");
  setenv("rbin", "/$zone/usw/offln/rbin");
  setenv("logfile", "offln.log");

  # mail distribution lists
  #
  setenv("DL_offln", "$DL_{DL_OFFLN}");
  setenv("DL_logxerr", "$DL_{DL_OFFLN_LOGXERR}");
  setenv("DL_opsrpt", "$DL_{DL_OPSRPT}");

  # execution parameters for reports
  #
  setenv("database_a", "uswoffln");
  setenv("database_b", "usw_perf");
  setenv("logxerr_size", "400000");
  
  # production name & file locations
  #
  setenv("remotehost", "$zone"); 
  setenv("remotelogin", "uswrpt"); 
  setenv("lgrpt_codir", "/$zone/loghist/uswprod01/co");
  setenv("lgrpt_codir2", "/$zone/loghist/uswprod02/co");
  setenv("lgrpt_dir", "/$zone/loghist/uswprod01/rpt");
  setenv("lgrpt_dir2", "/$zone/loghist/uswprod02/rpt");
  setenv("lgrej_dir", "/$zone/loghist/uswprod01/rej");
  setenv("lgrej_dir2", "/$zone/loghist/uswprod02/rej");
  setenv("lgper_dir", "/$zone/loghist/uswprod01/per");
  setenv("lgper_dir2", "/$zone/loghist/uswprod02/per");
  setenv("qcheck_dir", "/$zone/loghist/uswprod01/qdata");
  setenv("qcheck_dir2", "/$zone/loghist/uswprod02/qdata");
  
  # archive directories for files & reports
  #
  setenv("arcdir_sum", "/$zone/usw/reports/daily/sum");
  setenv("arcdir_vol", "/$zone/usw/reports/daily/vol");
  setenv("arcdir_per", "/$zone/usw/reports/daily/per");
  setenv("arcdir_logxerr", "/$zone/usw/reports/daily/logx_err");
  setenv("arcdir_opsrpt", "/$zone/usw/reports/daily/opsrpt");
  
  # run the script 
  #
  if ( $rtn_val = system ("$ENV{rbin}/offln.pl", @ARGV)) {
    print "$rtn_val from $0\n";
  }
}
