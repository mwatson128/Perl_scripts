#!/usr/local/bin/perl
#############################################################################
##  Purpose: This script will query the production database for the given  ##
##           time range (default to yesterday if no dates given) to get    ##
##           downtime data.  The results are formatted and emailed out.    ##
##-------------------------------------------------------------------------##
##  Input  : All optional.  See Usage statement below for details.         ##
##  Output : Downtime information based upon user input.                   ##
##  Invokes: Informix's dbaccess and Unix sendmail                         ##
##-------------------------------------------------------------------------##
##  Author : Kevin Daniel (kevind2)                                        ##
##  Date   : 09/06/07 - Initial version                                    ##
#############################################################################
use Getopt::Long;
use Time::Local;
use POSIX;

#########################################
#----------# Initializations #----------#
#########################################

## Variables for retrieving command line options
$oneday = 86400;
$yesterday = (time - $oneday);
$verbose = 1;
$conns = "";
$addrs = "";
$start_date;
$end_date;
$exceed = 0;

## Host/environment specific variables
$sendmail   = "/usr/lib/sendmail -t";              #how to send the mail
chomp($zone = `uname -n`);                         #everything is based on this
$ifx_svr    = "$zone"."_1";                        #informix server
$ifx_dir    = "/informix-$zone"."_1";              #informix path
$ifx_sql    = "$ifx_dir/etc/$ifx_svr.sqlhosts";    #informix sqlhosts
$dbaccess   = "$ifx_dir/bin/dbaccess";             #path to dbaccess app
$ENV{'INFORMIXSERVER'} = $ifx_svr;                 #set INFORMIXSERVER
$ENV{'INFORMIXDIR'}    = $ifx_dir;                 #set INFORMIXDIR
$sub_dir    = strftime("%m%y", gmtime);            #use 'MMYY' subdir for logs
$log_dir    = "/$zone/loghist/uswprod01/awklogs/$sub_dir";   #path for log files
$logfile    = "$log_dir/dt_report.log";            #application log
$db         = "usw_perf";                          #database to read from
$table      = "downtime";                          #table to read from
$field      = "time_d";                            #field containing dates

## Stuff for sending the email
$From       = "USW Reports<uswrpt\@$zone.pegs.com>";
$Subject    = "Downtime Report";

## Variables for 'pretty printing' the results
$header = "SDate    STime      EDate    ETime      Duration";
$spacer = "------------------------------------------------------";
#########  08/08/07 11:00:00   08/08/07 11:10:29   10m,29s
@padding = (22,22,8);
foreach $n (@padding) { $span += $n; }
$space = " ";
$delim = "=";


##########################################
#-------------# Begin Main #-------------#
##########################################
## Print Usage and exit if requested
if ($ARGV[0] eq "help") { &Usage; exit; }

## Open the log for output
open (LOG, ">>$logfile");
$date = strftime("%D", gmtime(time));
$now = strftime("%T", gmtime);
print LOG "[$now] =============== $date ===============\n";
print LOG "[$now] Using INFORMIXSERVER $ifx_svr\n";
print LOG "[$now] Using INFORMIXDIR $ifx_dir\n";

&GetArgs;      ## Get all the command line options
&ParseDate;    ## Figure out which date range to process
&ProcessSQL;   ## Prepare and Run the SQL query
&ParseResults; ## Format the results
&ShowResults;  ## Show results, either to STDOUT or via email

## Close the log file
close (LOG);

###########################################
#-------------# End of Main #-------------#
#----------# Subroutines Below #----------#
###########################################


##########################################
## Read all the options off the command ##
## line and store them appropriately.   ##
##########################################
sub GetArgs {
  GetOptions ("help" => sub {&Usage; exit;},
              "t=s" => \$start_date,
              "u=s" => \$end_date,
              "d=i" => \$exceed,
              "c=s" => \$conns,
              "a=s" => \$addrs);

  ## If email address list was supplied, first
  ## validate them, then assign the results
  ## (semicolon delimited) to the $To variable
  if ($addrs) {
    @try = split(/\|/, $addrs);

    ## Check for a valid format: xxx@yyy.zzz
    foreach $add (@try) {
      if ($add =~ /[a-zA-Z0-9.-_]+\@[a-zA-Z0-9.-_]+\.[a-z]+/) {
        push(@good, $add);
      } else {
        push(@bad, $add);
      }
    }

    ## As long as we have at least one, toggle verbose
    if (scalar(@good) > 0) {
      $verbose = 0;
      $To = join(";", @good);
    }

    ## Report any invalid email addresses found
    if (scalar(@bad) > 0) {
      if ($verbose) {
        print "Ignoring the following invalid email addresses:\n";
	foreach $b (@bad) { print " - $b\n"; }
      }
      print LOG "Ignoring the following invalid email addresses:\n";
      foreach $b (@bad) { print LOG " - $b\n"; }
    }
  }

  ## If conn list was supplied, put it into a hash
  if ($conns) {
    foreach $conn (split(/\|/, $conns)) {
      $connlist{$conn} = 1;
    }
  }

} # End sub GetArgs


###########################################
## Get the date to use in the sql query. ##
## If given, use the command line value. ##
## If not, generate yesterday's date.    ##
###########################################
sub ParseDate {

  if ($start_date =~ /(^\d\d$)/) {
    $mstart = $1; $mstop = $1;
    $dstart = 1;
    $today = strftime("%m", gmtime);
    $ystart =  strftime("%Y", gmtime);
    if ($today < $mstart) { $ystart--; }
    $ystop = $ystart;
    $ynext = $ystart;
    $mnext = (($mstart + 1) % 12);
    if ($mnext < $mstart) { $ynext++; }
    $dstop = strftime("%d", gmtime(timelocal(0,0,12,1,$mnext-1,$ynext-1900) - $oneday));
    if ($end_date =~ /(^\d\d$)/) { $mstop = $1; }
  } elsif ($start_date =~ /^(\d\d)(\d\d)$/) {
    $mstart = $1; $mstop = $1;
    $dstart = $2; $dstop = $2;
    $ystart =  strftime("%Y", gmtime);
    $ystop = $ystart;
    if ($end_date =~ /(\d\d)(\d\d)/) {
      $mstop = $1;
      $dstop = $2;
    }
  } elsif ($start_date =~ /(\d\d)(\d\d)(\d\d\d\d)/) {
    $mstart = $1; $mstop = $1;
    $dstart = $2; $dstop = $2;
    $ystart = $3;
    if ($end_date =~ /(\d\d)(\d\d)(\d\d\d\d)/) {
      $mstop = $1;
      $dstop = $2;
      $ystop = $3;
    }
  } else {
    $mstart = $mstop = strftime("%m", gmtime($yesterday));
    $dstart = $dstop = strftime("%d", gmtime($yesterday));
    $ystart = $ystop = strftime("%Y", gmtime($yesterday));
  }

  ## Given all the date stuff above, determine the start/stop values
  $start = timelocal("00","00","00",$dstart,$mstart-1,$ystart-1900);
  $stop  = timelocal("59","59","23",$dstop,$mstop-1,$ystop-1900);

  $formatted_date = strftime("%D", gmtime($start));
  if ($start < ($stop - $oneday)) {
    $formatted_date .= " to " . strftime("%D", gmtime($stop));
  }
  $now = strftime("%T", gmtime);
  if ($verbose) {
    print "Processing: from [$mstart/$dstart/$ystart 00:00:00] to [$mstop/$dstop/$ystop 23:59:59]\n";
    print LOG "[$now] Manually Processing: $mstart/$dstart/$ystart 00:00:00 to $mstop/$dstop/$ystop 23:59:59 ($start to $stop)\n";
  } else {
    print LOG "[$now] Processing: $mstart/$dstart/$ystart 00:00:00 to $mstop/$dstop/$ystop 23:59:59 ($start to $stop)\n";
  }

} # End sub ParseDate


#####################
## Process the SQL ##
#####################
sub ProcessSQL {

  ## Define the file names
  $DT_results = "$log_dir/DTresults.$$";
  $tmpsqlfile = "$log_dir/tmpDTquery.$$";

  ## Generate the SQL query
  $sql = "UNLOAD TO $DT_results " .
         "SELECT time_d, time_u, conn FROM $table " .
         "WHERE $field >= '$start' AND $field <= '$stop' " .
	 "AND (time_u - time_d) >= $exceed " .
         "ORDER BY conn, time_d;";
  open (OUT, ">$tmpsqlfile");
  print OUT "$sql\n";
  close (OUT);

  ## Run the query
  $now = strftime("%T", gmtime);
  if ($verbose) { print "[$now] Querying database: '$db'.\n"; }
  print LOG "[$now] Querying database: '$db'\n";
  system("$dbaccess $db < $tmpsqlfile > /dev/null 2>&1");

  ## Exit if there was an error
  if ($?) {
    $now = strftime("%T", gmtime);
    print LOG "[$now] !Error ($!) - Unable to perform query:\n$sql\n";
    close(LOG);
    system("rm $tmpsqlfile");
    if ($verbose) { die "!Error ($!) - Unable to perform query:\n$sql\n"; }
    exit;
  }

  ## Otherwise, success
  $now = strftime("%T", gmtime);
  if ($verbose) { print "[$now] Query completed.\n"; }
  print LOG "[$now] Query completed.\n";

  ## Read in the data from the unload file
  open(FILE, "$DT_results");
  @results = <FILE>;
  close(FILE);

  ## Clean up the temp files
  system("rm $DT_results");
  system("rm $tmpsqlfile");

} # end sub ProcessSQL


################################################
## Parse the results, formatting each row and ##
## storing it into a new array which can be   ##
## used to either print to the screen or to   ##
## send in an email.                          ##
################################################
sub ParseResults {
  $current = "";
 
  foreach $row (@results) {

    ## Split the fields
    ($this_start, $this_end, $this_conn) = split(/\|/, $row);

    ## Group similar connections
    #if ($this_conn =~ /([^_]+)/) { $this_conn = $1; }
    $fuzzy = $1;
  
    ## If no conns were passed in, include this one as 'valid'
    if (!$conns) { $connlist{$this_conn} = 1; }

    ## If this conn is valid, process it
    if ($connlist{$this_conn}) {

      ## If this_conn differs from current, print a new header
      if ($this_conn ne $current) {
        $current = $this_conn;
        $clen = length($current) + 14;
        $border = $delim x $clen;
        push(@FormattedOutput, $space);
        push(@FormattedOutput, $space);
        push(@FormattedOutput, $border);
        push(@FormattedOutput, "Downtime for $current:");
        push(@FormattedOutput, $border);
        push(@FormattedOutput, $header);
        push(@FormattedOutput, $spacer);
      }

      ## Evaluate the duration and format all the values
      $dur = $this_end - $this_start;
      $dur_min = int($dur / 60);
      $dur_sec = $dur % 60;
      $mgap = 3 - length($dur_min);
      $sgap = 2 - length($dur_sec);
      $formatted_dur = $space x $mgap . $dur_min . "m," . $space x $sgap . $dur_sec . "s ($dur)";
      $formatted_start = strftime("%D %T", gmtime($this_start));
      $formatted_end = strftime("%D %T", gmtime($this_end));
      push(@FormattedOutput, "$formatted_start   $formatted_end   $formatted_dur");
    }
  }
} # End sub ParseResults


###########################################
## By default, verbose is turned on and  ##
## output is sent to the screen.  If the ##
## -a option was used, send email to the ##
## given recipients instead and do not   ##
## print anything to the screen.         ##
###########################################
sub ShowResults {

  if ($verbose) {
    foreach $row (@FormattedOutput) { print "$row\n"; } ## Print the results to STDOUT
  } else {
    &SendEmail; ## Send the results in an email to the intended recipient(s)
  }

} # End sub ShowResults


###########################################
## Print the parsed db results in a nice ##
## format and send them out in an email. ##
## (if verbose, print to the screen too) ##
###########################################
sub SendEmail {

  ## send the results to the desired recipients
  $Subject .= " for $formatted_date";
  if ( !open(STATS, "|$sendmail") ) {
    die "!Error - Unable to open $sendmail!\n";
  }
  print STATS "From: $From\n";
  print STATS "To: $To\n";
  print STATS "Subject: $Subject\n";
  print STATS "Content-type: text/html\n\n";
  print STATS "<html><body><pre>";
  foreach $row (@FormattedOutput) { print STATS "$row\n"; }
  print STATS "</pre></body></html>";
  close (STATS);

  ## Print status to log
  $now = strftime("%T", gmtime);
  print LOG "[$now] Processing complete.  Email sent to:\n $To\n\n";

} # End sub SendEmail


##################################
## Display the usage statement. ##
##################################
sub Usage {
  my $e;
  print "Usage: downtime_report.pl [[-]help]\n";
  print "                          [-t MM[DD[YYYY]]]\n";
  print "                          [-u MM[DD[YYYY]]]\n";
  print "                          [-d duration]\n";
  print "                          [-c conn[,conn[,...]]]\n";
  print "                          [-a email_addr[|email_addr[|...]]]\n";
  print "All parameters are optional.  Supply [-]help to see this usage statment.\n";
  print "No parameters will do the previous day only for all connections.\n";
  print "Possible date combinations (using -t and -u):\n";
  print " -1 param  (-t only); 2 digit num: assumes month.\n";
  print " -1 param  (-t only); 4 digit num: assumes month and day.\n";
  print " -1 param  (-t only); 6 digit num: assumes month day and year.\n";
  print " -2 params (-t & -u); two 2 digit nums: assumes start and end month.\n";
  print " -2 params (-t & -u); two 4 digit nums: assumes start and end month and day.\n";
  print " -2 params (-t & -u); two 6 digit nums: assumes start and end month day and year.\n";
  print " Optional duration (using -d): only report downtimes that exceeded\n";
  print "    this value.  Expected unit is seconds, so use '120' rather than '2'\n";
  print "    when requesting a report with downtimes lasting >= to 2 minutes.\n";
  print " Optional connection name(s) (using -c) (pipe delimited if multiple):\n";
  print "    only report on the specified connections rather than all connections.\n";
  print "    Alternately, include a dash (-) in front of the connection name to\n";
  print "    explicitly excluded it from the result set.\n";
  print " Optional email address(es) (using -a) (pipe delimited if multiple):\n";
  print "    report results via email to the recipient(s) listed with this option.\n";
  print "    By specifying this option, verbose printing is automatically turned\n";
  print "    off (this for easier implementation within cron)\n";
} # End sub Usage
