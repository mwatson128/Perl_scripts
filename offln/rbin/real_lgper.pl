#!/bin/perl
#*TITLE - lgper.pl - Perl script to run daily offline processes - 1.27
#*SUBTTL Preface, and environment 
#
#  (]$[) lgper.pl:1.27 | CDATE=14:16:27 02/05/07
#
#
#	Copyright (C) 1996-2005 THISCO, Inc.
#	      All Rights Reserved
#
#

# internal global variables
($lgpersum_file, @lgpersum_file, @lgper_file, @lgper_missing);
($lgper_dir, $arcdir_per);
$zone = `uname -n`;
chomp $zone;
$zone_informixserver = $zone . "_1";
$zone_informixdir = "/informix-" . $zone . "_1";

$SUM = 0;
$LD  = 1;
$GZ  = 2;

#*SUBTTL lgper_init - initialize variables for LGPER processing
#
# lgper_init()
#
# initialize variables for processing of LGPER information
#
# parameters:
#   none
#
# globals:
#   @lgper_file		- the separate LGPER log files
#   @lgpersum_file	- the separate summary files
#   $lgpersum_file	- the united summary file
#   $lgper_dir		- directory from which LGPER files are retrieved
#   $arcdir_per		- directory into which LGPER SUM files are stored
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

{ 

  # Start off in the correct dir
  chdir ${rundir};

  # parameters set from environment variables
  # (others are set in offln.pl)
  $lgper_dir = $ENV{lgper_dir};
  $lgsum_dir = $ENV{lgsum_dir};
  $arcdir_per = $ENV{arcdir_per};
  
  # date strings for input/output files
  my($cdate) = `getydate -t ${date} -d 0`;
  my($csubdate) = `getydate -t ${date} -d 0 -L | cut -c1-4`;
  chomp($csubdate);

  # date strings for names of old files (to remove before starting)
  my($y_cdate) = `getydate -t ${date} `;
  my($y_csubdate) = `getydate -t ${date} -L | cut -c1-4`;
  chomp($y_csubdate);

  $DBUG && print DJUNK "\nLGPER\n-----\n";
  $DBUG && print DJUNK "INPUT, OUTPUT, & Yesterday's FILES\n";

  # input files
  $lgpersum_file = "per${cdate}.sum";
  $lgperld_file = "per${cdate}.ld";

  $DBUG && print DJUNK "lgpersum_file: $lgpersum_file\n";
  foreach $i (00..23) {
    if (10 > $i) {
      $hr = "0$i";
    }
    else {
      $hr = "$i";
    }
    $file_date = $csubdate . $hr;

    # test for existance of the logfiles, before putting them into the list.
    # if some are missing, keep a record of which ones.
    $loc_sum = "per$file_date.sum";
    $loc_gz = "per$file_date.sum.gz";
    $loc_ld = $rundir . "ld" .  $file_date . ".cfg";
    $days_files{$file_date}[$LD] = $loc_ld;

    $dir_file_sum = $lgsum_dir . "/" . $loc_sum;
    $dir_file_gz = $lgsum_dir . "/" . $loc_gz;

    # A little short circuit here.  If the unzipped file is in the dir
    # just get it, gz is set to "-".
    if (-e $dir_file_sum) {
      $days_files{$file_date}[$SUM] = $loc_sum;
      $days_files{$file_date}[$GZ] = "-";
    }
    # if the sum isn't there, check for gz
    elsif (-e $dir_file_gz) {
      $days_files{$file_date}[$SUM] = $loc_sum;
      $days_files{$file_date}[$GZ] = $loc_gz;
    }
    # Looks like neither are there.
    else {
      $days_files{$file_date}[$SUM] = "-";
      $days_files{$file_date}[$GZ] = "-";
      $lgper_missing[$i] = "per${csubdate}${hr}.sum";
    }

    $lgper_yesterfile[$i] = "per${y_csubdate}${hr}.lg";
    $DBUG && print DJUNK "lgper_yesterfile[${i}]: $lgper_yesterfile[$i]\n";
    $DBUG && print DJUNK "lgper_gz file: $dir_file_gz\n";
    $DBUG && print DJUNK "lgpersum file: $dir_file_sum\n";
    $DBUG && print DJUNK "lgper_ld file: $loc_ld\n";
  }

  # check for missing log files
  if (@lgper_missing) {
    $DBUG && printf DJUNK "missing log files!: %s\n", 
      join(" ", @lgper_missing);
    printf LOGFILE "\nWARNING. LGPER files absent: %s\n", 
      join(" ", @lgper_missing);
    local($lgper_missing_mail) = "\t%s\n", join("\n\t", @lgper_missing);
  }
}

#*SUBTTL lgper - run thread for LGPER processing
#
# lgper()
#
# run entire thread for processing of LGPER information
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

sub lgper 
{

  LOGENTER("LGPER");
  !($rtn_val = &lgper_db) || return($rtn_val);
  LOGEXIT("LGPER");

  return($rtn_val);
}

#*SUBTTL lgper_db - run the LGPER database processing and dependants
#
# lgper_db()
#
# run the database loading sub-thread for processing of LGPER information
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

sub lgper_db 
{

  LOGENTER("LGPER_DB");
  !($rtn_val = &lgper_p2tally) || return($rtn_val); #parallel
  !($rtn_val = &lgper_a2optally) || return($rtn_val); 
  LOGEXIT("LGPER_DB");

  return($rtn_val);
}

#*SUBTTL lgper_archive - archive LGPER output files and compress
#
# lgper_archive()
#
# archive the summary files to their directories & compress them
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

sub lgper_archive 
{

  LOGENTER("LGPER: ARCHIVE");

  # ensure that the sumfile doesn't get removed if the archive fails
  my($notarc) = "ARC.${lgpersum_file}.notarc";
  system("touch ${notarc}");

  # archive the LGPER-SUM file
  print(LOGFILE "start for archive of ${lgpersum_file}: ", `date`);
  if ($rtn_val = &archive(${arcdir_per}, ${lgpersum_file})) {

    # there was an error.  call error handler and exit
    $rtn_val = warn_out($W_ARCHIVEPER, $rtn_val);
    return($rtn_val);
  }
  else {

    # the archive completed successfully, remove the notarc file
    system("rm -f ${notarc}");
  }

  # ensure that the ubsumfile doesn't get removed if the archive fails
  my($notarc) = "ARC.${lgperubsum_file}.notarc";
  system("touch ${notarc}");

  LOGEXIT("LGPER: ARCHIVE");

  return($rtn_val);
}

#*SUBTTL lgper_p2tally - run db tally LGPER message volume information
#
# lgper_p2tally()
#
# tally the lgper message volume information using P2TALLY---first purging
# any data that lay in the target table (A2PERF) for the period to be run.
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

sub lgper_p2tally 
{

  LOGENTER("LGPER: P2TALLY");

  # see if LGPER SUM file is in 'execute directory'
  # if not check in the archive directory, and uncompress it
  # write a function that does this for all tally programs

  # calculate date 6 days ago.
  my($odate) = `getydate -t ${date} -s -d -6`;
  # expire information that is 10 days old from a2perf
  print(LOGFILE "start of EXPIRE of A2PERF for ${odate}: ", `date`);
  $options = "-d ${database_b} -t ${odate} -n a2perf -f ddate";
  if ($rtn_val = system("expire $options >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEA2PERF, $rtn_val);
    return($rtn_val);
  }
  
  # purge today's information from a2perf
  print(LOGFILE "start of PURGE of A2PERF for ${date}: ", `date`);
  $options = "-d ${database_b} -t ${date} -n a2perf -f ddate";
  if ($rtn_val = system("purge $options >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEA2PERF, $rtn_val);
    return($rtn_val);
  }

  # create one summary file from the many
  print(LOGFILE "P2TALLY for each sum file ${date}: ", `date`);

  # Clear out to ld file
  my($catcommand) = "cat /dev/null > $lgperld_file  2>> $logfile";
  !DBUG || print (DJUNK "catcommand: ${catcommand}\n");
  if ($rtn_val = system("$catcommand")) {

    # there was an error.  call error handler and exit
    error_out(E_LGPERXCAT, $rtn_val);

    return($rtn_val);
  }

  # Create command line options for DBLOAD
  $options  = " -d ${database_b}";           # specify the database
  $options .= " -n 50000";                   # specify the commit interval
  $options .= " -l dbload.errors";           # specify the error log file
  $options .= " -r";                         # load without locking table

  # shortcut to dbload command
  $dbld = "$zone_informixdir/bin/dbload";

  # Start of p2tally and dbload for the per files.
  foreach $i (sort keys %days_files) {

    !DBUG || print (DJUNK "in file for loop $i \n");
    print LOGFILE "  --$i: ", `date`;

    # Simplify the file names
    $sum_file = $days_files{$i}[$SUM];
    $gz_file = $days_files{$i}[$GZ];
    $ld_file = $days_files{$i}[$LD];
    !DBUG || print (DJUNK "ld file = $ld_file \n");
    !DBUG || print (DJUNK "sum file = $sum_file \n");
    !DBUG || print (DJUNK "gz file = $gz_file \n");

    if ($sum_file eq "-" && $gz_file eq "-") {
      print(LOGFILE "    Skipping DBLOAD for $i, File missing!\n");
      next;
    }

    # Move the $i file from $lgsum_dir and gunzip
    if ($gz_file ne "-") {
      !DBUG || print (DJUNK "get the GZ file \n");
      system "cp ${lgsum_dir}/${gz_file} . >>$logfile 2>>$logfile";
      system "gunzip ${gz_file} >>$logfile 2>>$logfile";
    }
    else {
      system "cp ${lgsum_dir}/${sum_file} . >>$logfile 2>>$logfile";
    }

    # Build the dbload config file for USW.
    #open(LDC, ">$dbld_config");
    open(LDC, "> ${ld_file}");
    print LDC "FILE $sum_file DELIMITER '|' 9;\n";
    print LDC "INSERT INTO a2perf;\n";
    close (LDC);

    # Run DBLOAD
    print(LOGFILE "    Start of DBLOAD for $i\n");
    system("$dbld -c $ld_file ${options} >> /dev/null 2>> $logfile");
    print(LOGFILE "    End of DBLOAD for $i at ", `date`);

    # create one summary file from each of the hourly ones...
    system("cat $sum_file >> $lgperld_file  2>> $logfile");

    # Remove the sum to save space if not in DBUG mode.
    #!DBUG || system("rm -f $sum_file");
    print "Going to: rm -rf $sum_file \n";
  }
  print(LOGFILE "End print and DBLOAD at ", `date`);

  system("cp ${lgperld_file} ${lgpersum_file}");

  # archive the LGPER OUTPUT
  !($rtn_val = &lgper_archive) || return($rtn_val);

  # delete LGPER SUM file, if it's safe to do so
  if (-e "ARC.${lgpersum_file}.notarc") {
    print LOGFILE "CANNOT REMOVE: archive of ${lgpersum_file} failed.\n";
  }
  else {
    system("rm -f  ${lgpersum_file}");
  }
  
  # remove load and config file for dbload
  system("rm -f  ${dbld_config}");
  system("rm -f  ${lgperld_file}");

  LOGEXIT("LGPER: P2TALLY");

  return($rtn_val);
}

#*SUBTTL lgper_a2optally - run db optimization of LGPER performance information
#
# lgper_a2optally()
#
# tally the LGPER performance information (by hour) using A2OPTALLY---first 
# purging any data that lay in the target table (A2PERF) for the 
# period to be run.
#
# parameters:
#   none
#
# globals:
#
# locals (inherited):
#   rtn_val     - return value to main; modifiable by all sub's called
#
# locals (defined):
#   none
# 
# mys:
#   none
#
# returns:
#   rtn_val     - return value from subroutines and commands
#

sub lgper_a2optally 
{
  LOGENTER("LGPER: A2OPTALLY");

  # purge information from a2operf
  print(LOGFILE "start of PURGE of A2OPERF for ${date}: ", `date`);
  if ($rtn_val = system("purge -d ${database_b} -t ${date} -n a2operf -f ddate >> $logfile 2>> $logfile")) {

    # there was an error.  call error handler and exit
    error_out($E_PURGEA2OPERF, $rtn_val);
    return($rtn_val);
  }

  # tally LGPER A2OPTALLY performance information (by day)
  print(LOGFILE "start of A2OPTALLY for ${date}: ", `date`);
  
  foreach $i (00..23) {
    if (10 > $i) {
      $hr = "0$i";
    }
    else {
      $hr = "$i";
    }

    # run a2optally for each hour 00 .. 23 
    $options = "-t ${date}_${hr}:00 -u ${date}_${hr}:59";
    if ($rtn_val = system("a2optally $options >> $logfile 2>> $logfile")) {

      # there was an error.  call error handler and exit
      error_out($E_A2OPTALLY, $rtn_val);
      return($rtn_val);
    }
  }

  print(LOGFILE "end of A2OPTALLY for ${lgpersum_file}: ", `date`);
  print(LOGFILE "end time of LGPER-SUM-PERFORMANCE thread is ", `date`, ".\n");

  LOGEXIT("LGPER: A2OPTALLY");

  return($rtn_val);
}

1;

#*SUBTTL structures for error_out and warning_out mailings:  lgper_rcp()
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

$E_LGPERMISSINGLOGS = { 'subject', "WARNING: Missing LGPER Log(s)", 
  'rs_here', "LGPER", 
'body', "there are one or more LGPER Logs missing:
${lgper_missing_mail}

This is not uncommon if the system crashed/was down during the day in 
question.  However, if there was no failover/fallover with significant
downtime, Operations should worry about where the missing file(s) 
disappeared to.  The files should be in ${lgper_dir}.

The process will continue to run, even with this warning.  If you think
people should be worried, notify someone the next working day (but wait
no longer than a week).

(There is no need to restart)
"};



$E_LGPERNOTOK = { 'subject', "LGPER thread failed", 
  'rs_here', "LGPER_EX", 
  'mf', "LGPER_DB", 
  'rs_higher_f', 1, 
  'rs_higher', "LGPER", 
'body', "the LGPER.notok file was in existance when this thread tried to run

Another LGPER thread could currently be running.  Check to be sure
that there isn't.  If another is running, wait for it to complete before
restarting.

Or a previous LGPER thread could have failed.  Check the ${logfile} and 
past mailings to determine if this is the case.  If so, see that the 
failed process is restarted.

To restart:
  o remove the file 'LGPER.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_RCPLGPER = {
  'subject', "RCP of LGPER files failed", 
  'rs_here', "LGPER_EX", 
  'mf', "LGPER_DB", 
  'rs_higher_f', 1, 
  'rs_higher', "LGPER", 
'body', "the remote copy of one of the LGPER files failed

Check to make sure that the remote file exists in ${remotehost}:${lgper_dir}/.
If it is not there, figure out why, and where it's gone to, then restart.

Check to make sure that the permissions are set up correctly on the remote 
machine (${remotehost}) for remote copying as the '${remotelogin}' login

Also this could be the result of the disk filling up.

To restart:
  o remove the file 'LGPER.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_RCPPSUM = {
  'subject', "LGPER file failed checksum", 
  'rs_here', "LGPER_EX", 
  'mf', "LGPER_DB", 
  'rs_higher_f', 1, 
  'rs_higher', "LGPER", 
'body', 
"checksum reported that the remote copy of one of the files was flawed

There may have been a flaw in the transfer of the file.  Double check the 
error by using the UNIX command 'sum' on the local and remote file.  The 
problem usually clears up if you just try again.

To restart:
  o remove the file 'LGPER.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

#*SUBTTL structures for error_out and warning_out mailings:  lgper_logx()
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


$E_LGPERXNOTOK = { 'subject', "LGPER thread failed", 
  'rs_here', "LGPER_LOGX", 
  'mf', "LGPER_DB", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the LGPER.notok file was in existance when LGPERX tried to run

Another LGPER thread  could currently be running.  Check to be sure that 
there isn't.  If another is running, wait for it to complete before 
restarting.

Or a previous LGPER thread could have failed.  Check the ${logfile} and 
past mailings to determine if this is the case.  If so, see that the 
failed process is restarted.

To restart:
  o remove the file 'LGPER.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_LGPERX = {
  'subject', "LGPER Extract program failed", 
  'rs_here', "LGPER_LOGX", 
  'mf', "LGPER_DB", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the program LGPERX bombed out on one of its 24 log files

The disk may have filled up.  If it has, remove any unneccessary files;
or (if all files are important) if other offline processes are running,
wait for them to archive their data files and free up some room (if the 
disk filling up didn't crash those processes as well).  If old data files
are filling up disk space, you may need to archive them by hand using the
'LGPER_ARC' or 'LGRPT_ARC' options to '$ENV{0}'.

If that's not it, check the ${logfile} to see what the problem was.  
If the trouble cannot be fixed, inform someone in the morning.

To restart:
  o remove the file 'LGPER.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

#*SUBTTL structures for error_out and warning_out mailings:  lgper_archive()
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


$E_LGPERXCAT = {
  'subject', "LGPER summary files failed to concatenate", 
  'rs_here', "LGPER_LOGX", 
  'mf', "LGPER_DB", 
  'rs_higher_f', 0, 
  'rs_higher', "", 
'body', "the concatenation of the hourly LGPERX files into ${lgper_file} failed

The disk may have filled up.  If it has, remove any unneccessary files;
or (if all files are important) if other offline processes are running,
wait for them to archive their data files and free up some room (if the 
disk filling up didn't crash those processes as well).  If old data files
are filling up disk space, you may need to archive them by hand using the
'LGPER_ARC' or 'LGRPT_ARC' options to '$ENV{0}'.

If that's not it, check the ${logfile} to see what the problem was.  
If the trouble cannot be fixed, inform someone in the morning.

To restart:
  o remove the file 'LGPER.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$W_ARCHIVEPER = {
  'subject', "ARCHIVE of LGPER summary file failed", 
  'rs_here', "LGPER_ARC", 
'body', "the archive of ${lgpersum_file} into ${arcdir_per}/ failed

512: No space left on device
The disk may have filled up.  If it has, you will need to remove old
or unneccessary files.  Procedures for dealing with this situation are
covered in Appendix A of the 'USW Offline-Processing Operations 
Procedures' document found on the website.

256: Permission denied
This file may already have been archived. If the archived file already
exists and is deemed bad, move it to a minus file and archive by hand.

If that's not it, check the ${logfile} to see what the problem was.  
If the trouble cannot be fixed, inform someone in the morning.

To archive by hand:
  o enter the command 'nohup $ENV{0} $date LGPER_ARC &'
"};


#*SUBTTL structures for error_out and warning_out mailings:  lgper_p2tally()
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


$E_P2TALLYNOTOK = { 
  'subject', "LGPER thread failed", 
  'rs_here', "P2TALLY", 
  'mf', "", 
  'rs_higher_f', 1, 
  'rs_higher', "LGPER_DB", 
'body', "the P2TALLY.notok file was in existance when this thread tried to run

Another P2TALLY could currently be running.  Check to be sure
that there isn't.  If another is running, wait for it to complete before
restarting.

Or a previous P2TALLY could have failed.  Check the ${logfile} and 
past mailings to determine if this is the case.  If so, see that the 
failed process is restarted.

To restart:
  o remove the file 'P2TALLY.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};


$E_PURGEA2PERF = {
  'subject', "LGPER's purge of the A2PERF table failed", 
  'rs_here', "P2TALLY", 
  'mf', "", 
  'rs_higher_f', 1, 
  'rs_higher', "LGPER_DB", 
'body', "the purge of the A2PERF table for ${date} (in ${database_b}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone in the morning.

To restart:
  o remove the file 'P2TALLY.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

$E_PURGEA2OPERF = {
  'subject', "LGPER's purge of the A2OPERF table failed", 
  'rs_here', "P2TALLY", 
  'mf', "", 
  'rs_higher_f', 1, 
  'rs_higher', "LGPER_DB", 
'body', "the purge of the A2OPERF table for ${date} (in ${database_b}) failed

This is a very strange thing to happen.  Double check to make sure no other
programs are trying to access this table at the same time, then restart.
If the trouble persists, inform someone in the morning.

To restart:
  o remove the file 'P2TALLY.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

$E_P2TALLY = {
  'subject', "LGPER's P2TALLY failed", 
  'rs_here', "P2TALLY", 
  'mf', "", 
  'rs_higher_f', 1, 
  'rs_higher', "LGPER_DB", 
'body', 
"the P2TALLY program failed to load data from ${lgper_file} into the database

Check the ${logfile} to see what the problem was.  Double check to make sure 
no other programs were trying to access this table at the same time, then 
restart.  If the trouble persists, inform someone in the morning.

To restart:
  o remove the file 'P2TALLY.notok'
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

$E_A2OPTALLY = {
  'subject', "LGPER's A2OPTALLY failed",
  'rs_here', "A2OPTALLY",
  'mf', "",
  'rs_higher_f', 0,
  'rs_higher', "",
'body',
"the A2OPTALLY program failed to load data from a2perf into the database
Check the ${logfile} to see what the problem was.  Double check to make sure 
no other programs were trying to access this table at the same time, then 
restart.  

If the trouble persists, inform someone immediately using the on-call
escalation procedures.

To restart:
  o restart with the command 'nohup $ENV{0} $date %s &'
"};

1;

