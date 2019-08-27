#!/usr/bin/perl 

use Getopt::Long;
use Time::Local;
use Excel::Writer::XLSX;
use Data::Dumper;
#use diagnostics;

sub usage;
sub cmdline;
sub do_init;
sub add_xls_headers;    
sub do_destbusy;
sub do_destdown;
sub do_context_to;
sub do_not_found;
sub fileNameInit;
sub zip_email;
sub fillInTabs;
sub doSummary;
sub doCharts;
sub populateSgaNames;

#####################################################################
## Initialize variables
##
#####################################################################

$help_cmd = 0;
$rm_all = 0;
$y = 0;
$setOldDstbMsg = 0;
$oldDstbMsg = "No stats are available until this IP is upgraded. \n";
$atLeastOneTO = 0;
$atLeastOneDB = 0;

$smallLimit = 15;
$bigLimit = 50;

# for SGA hash
$TMO = 0;
$DSTB = 1;
$DSDN = 2;

# For main info hash
$MSN = 0;
$GDS = 1;
$SGA = 2;
$CHN = 3;
$MSGT = 4;
$ORGT = 5;
$ARVT = 6;
$DIFF = 7;

# the TM and DB counts by CHN and min are in the main hash
# as the hash tmByMin and dbByMin

$tmoPals = $tmoAals = $tmoRpin = $tmoBook = $tmoNoAns = $tmoTotal = 0;
$dstbPals = $dstbAals = $dstbRpin = $dstbBook = $dstbNoAns = $dstbTotal = 0;
$monday = "";

############
##  Main  ##
############

# call command line parsing funciton
cmdline();

# Initialize/load variables and default values
do_init();
populateSgaNames();

$IFP2 = "< $tmpfile";
open IFP2 or die "Can't open IFP2 $IFP2\n";
while (<IFP2>) { 
  chomp;
  $ln = $_;

  # Get time from record
  if ($ln =~ (/(\d\d)\/(\d\d)\/(\d\d) (\d\d):(\d\d):\d\d/)) {
    $rec_time = timegm($6,$5,$4,$2,($1 - 1),($3 + 2000));
  }
  else {
    print " doesn't have a time. \n$ln\n";
  }

  # if past_hours then make sure this line is in the time restraint
  if ($past_hours) {
   # cutoff_time calculated in do_init
    next if ($rec_time < $cutoff_time);
  }
  $tmKey = $rec_time;

  if ($ln =~ /Destination Denied/) {
    do_destdown();
    $atLeastOneDN = 1;
  }

  if ($ln =~ /Destination busy/) {
    do_destbusy();
    $atLeastOneDB = 1;
  }

  if ($ln =~ /Context timeout/) {
    do_context_to();
    $atLeastOneTO = 1;
  }

  if ($ln =~ /Cannot find USW message/) {
    do_not_found();
  }
}


# Figure out the file name 
fileNameInit();

$workbook = Excel::Writer::XLSX->new("$xlResultsName");
add_xls_headers();    

fillInTabs();
doSummary();
doCharts();


$workbook->close();
close IFP2;

print "output is in /$zone/usw/timeout_rpt/$xlResultsName\n";

zip_email();

`mv $xlResultsName $resultDir`;
`rm $tmpfile`;

exit;

###################
##  End of Main  ##
###################


#####################################################################
## Process the command line options
##
#####################################################################
sub cmdline() {

  GetOptions (
    'c|chn=s' => \$inputChn,
    'h|help' => \$help_cmd,
    'f|file=s' => \$filename,
    'r|rtdir=s' => \$user_rtdir,
    'd|day=s' => \$cmd_day,
    'e|email=s' => \$email_add,
    'a|all' => \$unfilter,
    's|short:1' => \$past_hours
  );

  $zone = `uname -n | cut -d . -f 1`;
  chomp($zone);

  if ($email_add) {
    $emails = "operations3\@dhisco.com pedpg\@dhisco.com $email_add"; 
    #$emails = "mike.watson\@dhisco.com $email_add"; 
  }
  else {
    $emails = "operations3\@dhisco.com pedpg\@dhisco.com";
    #$emails = "mike.watson\@dhisco.com";
  }

  if ($help_cmd == 1) {
    usage();
    exit();
  }
  elsif ($inputChn eq "" && $unfilter != 1) {
    usage();
    exit();
  }
  elsif ($past_hours && $cmd_day) {
    usage();
    exit();
  }
}

#####################################################################
## Usage printing function
##
#####################################################################
sub usage() {

  print "Usage: timeout_trace.pl <options> -c <CHN> \n";
  print "  -c is required. \n";
  print "  Will find CHN's timeouts in the current rtlog and put \n";
  print "  them in an excel spreadsheet to be sent to the customer. \n";
  print "  You can find the result in the /zone/usw/timeout_rpt \n";
  print "  directory, and also in email. \n";
  print "  Options:\n";
  print "  -(h|help)           - Print this help message \n";
  print "  -(c|chn) CHN        - any USW chain code. \n";
  print "  -(d|date) <0-31>    - day to use, only for last month\n";
  print "  -(e|email) email\@something.com - send to this email also.\n";
  print "  -(f|file) rtlogfile - file to use instead of regular rtlog\n";
  print "  -(r|rtdir) log dir  - directory to use instead of regular dir\n";
  print "  -(s|short) <1-24>   - grab last X hours, empty = 1 hour.\n\n";

}

#####################################################################
## Initialize variables and load in default values.
##
#####################################################################
sub do_init() {

  # Before we do too much, lets check if another is running.
  #  If there is, then print and exit.
  @psTimeouttrace = `ps -ef | grep timeout_trace | grep -v grep`;
  $psCnt = @psTimeouttrace;
  if (2 == $psCnt) {
    print '#' x 70;
    print "\nA timeout_trace is already running.  Try again in a few minutes. \n";
    print '#' x 70, "\n";
    exit;
  }

  # get the month and year, only days is given on cmdline
  $mon = `date -u '+%m'`;
  $yr = `date -u '+%y'`;
  chomp $mon;
  chomp $yr;
  $fnamMon = $mon;
  $monday = sprintf "%02d%02d", $mon, $yr;
  # for gmtime, month is 0 based, so take away one
  $mon -= 1;

  $curday = `date -u '+%d'`;
  if ($cmd_day) {
    # If the day asked for is greater than today, take one from month
    if ($cmd_day > $curday) {
      $mon -= 1;
      if ($mon == 12) {
	$yr -= 1;
      }
    }
    $curMonth = $mon;
    $curYear = $yr;
  }
  else {
    $cmd_day = $curday;
    $curMonth = $mon;
    $curYear = $yr;
  }

  # define filename
  if ($filename eq "") {
    if ($cmd_day) {
      # will convert day to int, dropping leading zero
      $cmd_day += 0;
      $filename = "rtlog" . $cmd_day;
    }
    else {
      $cmd_day = `date -u '+%d'`;
      chomp($cmd_day);
      # will convert day to int, dropping leading zero
      $cmd_day += 0;
      $filename = "rtlog" . $cmd_day;
    }
  }
  $fnamDay = sprintf "%02d%02d%02d", $fnamMon, $cmd_day, $yr;

  # Using the LOGNAME env variable to set default values
  if ($zone eq "dhscprdctpe01al") {
    print '#' x 70;
    print "\nPlease run this script on uswprodsd01  \n";
    print '#' x 70, "\n";
    exit;
  }
  elsif ($zone eq "dhscprdcdce01al") {
    $rtdir = "/dhscprdcdce01al/logs/rtlogs/";
    $resultDir = "/$zone/usw/timeout_rpt/";
    $sgaInputFile = "/$zone/scripts/sganame.cfg";
  }
  elsif ($ENV{LOGNAME} eq "uswrpt") {
    $sgaInputFile = "/$zone/research/tmtrace/sganame.cfg";

    if (-e $filename) {
      $rtdir = "./";
    }
    else {
      $supdir = "/$zone/loghist/uswprod01/rtlogs/$monday";
      qx(cp ${supdir}/${filename}* .);
      qx(gunzip $filename);
      $rtdir = "./";
      $rm_all = 1;
    }
    $resultDir = "./timeout_rpt/";
  }
  else {
    $rtdir = "./";
  }

  if (defined $user_rtdir) {
    $rtdir = $user_rtdir . "/";
  }

  # Figure out time now and time $past_hours ago
  if ($past_hours) {
    # Set Month / Day just in case it isn't entered on the command line
    $cur_time = time();
    $cutoff_time = $cur_time - ($past_hours * 3600);

    # get an hour for the filename
    ($seconds, $minutes, $hours, $day_of_month, $month, $year,
     $wday, $yday, $isdst) = gmtime($cutoff_time);
    $file_day_end = $hours;

    $startTime = $cutoff_time;
    $stopTime = $cur_time;
  }

  ########################################################################
  # To solve the problem where a search for "DI" would also match
  # HDI-A2 and pull in timeouts not related to "DI" I put in the v_grep
  # variables.  These are used in egrep -v fashion to eleminate H* and G*
  # matches if present.  
  #
  # If anyone thinks of a smoother way to do this you can change it.
  ########################################################################
  $chain_grep = "";
  $v_grep = "";
  if ($inputChn) {
    $tmpfile = "${inputChn}_rtfile";
    if ($inputChn =~ m/,/) {
      @inputChnArr = split (/,/, $inputChn);
      foreach $part (@inputChnArr) {
        $chnHash{$part} = $part;
        $chain_grep .= $part . "-A2|";
        $v_grep .= "H" . $part . "-A2|";
        $v_grep .= "G" . $part . "-A2|";
      }
      $chain_grep = substr($chain_grep, 0, -1);
      $v_grep = substr($v_grep, 0, -1);
      `egrep "$chain_grep" ${rtdir}${filename} | egrep -v "$v_grep" > $tmpfile`;
    }
    else {
      $chnHash{$inputChn} = $inputChn;
      $chain_grep = $inputChn . "-A2";
      $v_grep .= "H" . $inputChn . "-A2|";
      $v_grep .= "G" . $inputChn . "-A2|";
      $v_grep = substr($v_grep, 0, -1);
      `grep $chain_grep ${rtdir}${filename} | egrep -v "$v_grep"  > $tmpfile`;
    }
  }
  else {
    $tmpfile = "all_rtfile";
    system ("cp ${rtdir}${filename} $tmpfile");
  }

  # Some lines are stuck together without any newline, so we need to
  # seperate them back out. Putting in seperate script so adding 
  # conditions will be easier.
  system ("./seperate.sh $tmpfile");

}

sub fileNameInit {

  # Open the file and write the header info
  if ($inputChn) {
    
    if ($inputChn =~ m/,/) {
      @fnameChns = split (/,/, $inputChn);
      foreach $subChn (@fnameChns) {
	$chnNames{$subChn} = $subChn;
      }
      $fname = join("_", @fnameChns, "");
    }
    else {
      $chnNames{$inputChn} = $inputChn;
      $fname = $inputChn;
    }

    if ($past_hours) {
      $xlResultsName = sprintf "%s_to_db_report_%s%s.xlsx", $fname, $fnamDay, 
		      $file_day_end;
      $zipResultsName = sprintf "%s_to_db_report_%s%s", $fname, $fnamDay, 
		      $file_day_end;
    }
    else {
      $xlResultsName = sprintf "%s_to_db_report_%s.xlsx", $fname, $fnamDay; 
      $zipResultsName = sprintf "%s_to_db_report_%s", $fname, $fnamDay; 
    }
  }
  else {
    if ($past_hours) {
      $xlResultsName = sprintf "all_to_db_report_%s_%s.xlsx", $fnamDay,
		      $file_day_end; 
      $zipResultsName = sprintf "all_to_db_report_%s_%s", $fnamDay,
		      $file_day_end; 
    }
    else {
      $xlResultsName = sprintf "all_to_db_report_%s.xlsx", $fnamDay,
      $zipResultsName = sprintf "all_to_db_report_%s", $fnamDay,
    }
  }
}

#####################################################################
## Do the dest busy searches through rtlog
##
#####################################################################
sub do_destbusy() {

  @flds = split /\s/, $ln;

  # Hash the fields that have one : that yields two values when split
  foreach $fld (@flds) {
    if ($fld =~ /:/) {
      ($title, $value) = split /:/, $fld;
      $fldHash{$title} = $value;
    }
  }

  #print Dumper (\%current_fld);

  if ($fldHash{MSN}) {

    $msn = $fldHash{MSN};
    # Group UA subchains together.
    if ( ($fldHash{SGA} eq "1V") || ($fldHash{SGA} eq "1C") ||
         ($fldHash{SGA} eq "1G") ) {
      $sga = "UA";
    }
    else {
      $sga = $fldHash{SGA};
    }

    $recChn = $fldHash{CHN};
    $recHrs = $fldHash{HRS};
    if ($recChn) {
      $dstbMsgHash{$msn}[$CHN] = $recChn;
    }
    elsif ($recHrs) {
      $dstbMsgHash{$msn}[$CHN] = $recHrs;
    }

    $ln =~ /= (\d+\/\d+\/\d+ \d+:\d+:\d+) /;
    $dstbMsgHash{$msn}[$ORGT] = $1;

    # tally up the SGA's
    $sgaNumbersHash{$sga}[$DSTB] += 1;
    $dstbSGAByTime{$tmKey}{$sga} += 1;

    $dstbMsgHash{$msn}[$MSN] = $msn;
    $dstbMsgHash{$msn}[$GDS] = $fldHash{GDS};
    $dstbMsgHash{$msn}[$SGA] = $sga;
    $dstbMsgHash{$msn}[$MSGT] = $fldHash{MTP};
  }
  else {
    $setOldDstbMsg = 1;
  }
}

#####################################################################
## Do the dest busy searches through rtlog
##
#####################################################################
sub do_destdown() {

  @flds = split /\s/, $ln;

  # Hash the fields that have one : that yields two values when split
  foreach $fld (@flds) {
    if ($fld =~ /:/) {
      ($title, $value) = split /:/, $fld;
      $fldHash{$title} = $value;
    }
  }

  if ($fldHash{MSN}) {

    $msn = $fldHash{MSN};
    # Group UA subchains together.
    if ( ($fldHash{SGA} eq "1V") || ($fldHash{SGA} eq "1C") ||
         ($fldHash{SGA} eq "1G") ) {
      $sga = "UA";
    }
    else {
      $sga = $fldHash{SGA};
    }

    $recChn = $fldHash{CHN};
    $recHrs = $fldHash{HRS};
    if ($recChn) {
      $dsdnMsgHash{$msn}[$CHN] = $recChn;
    }
    elsif ($recHrs) {
      $dsdnMsgHash{$msn}[$CHN] = $recHrs;
    }

    $ln =~ /= (\d+\/\d+\/\d+ \d+:\d+:\d+) /;
    $dsdnMsgHash{$msn}[$ORGT] = $1;
    $sgaNumbersHash{$sga}[$DSDN] += 1;
    $dsdnSGAByTime{$tmKey}{$sga} += 1;

    $dsdnMsgHash{$msn}[$MSN] = $msn;
    $dsdnMsgHash{$msn}[$GDS] = $fldHash{GDS};
    $dsdnMsgHash{$msn}[$SGA] = $sga;
    $dsdnMsgHash{$msn}[$MSGT] = $fldHash{MTP};
  }
  else {
    $setOldDstbMsg = 1;
  }
}

#####################################################################
## Do the context timeout searches through rtlog
##
#####################################################################
sub do_context_to() {

  @flds = split /\s/, $ln;

  # Hash the fields that have one : that yields two values when split
  foreach $fld (@flds) {
    if ($fld =~ /:/) {
      ($title, $value) = split /:/, $fld;
      $current_fld{$title} = $value;
    }
  }

  # New timeout code calls it MSN, older code calls it msgno
  if ($current_fld{MSN}) {
    $msn = $current_fld{MSN};
  }
  elsif ($current_fld{msgno}) {
    $msn = $current_fld{msgno};
  }

  # Context timeout looks like:
  # [USWPRODCE08] <= 12/01/14 21:06:21 (DI-A2) EX(A3IPCTTM): 
  # Context timeout: 12/01/14 21:06:15 HRS:DI CHN:DI GDS:UA SGA:1V 
  # MSN:046C47CD846F42 MTP:AALS =>

  # New timeout code contains CHN, older code has only HRS
  $recChn = $current_fld{CHN};
  $recHrs = $current_fld{HRS};
  if ($recChn) {
    $tmoMsgHash{$msn}[$CHN] = $recChn;
    $tmoCntBC{$tmKey} {$recChn} += 1;
  }
  elsif ($recHrs) {
    $tmoMsgHash{$msn}[$CHN] = $recHrs;
    $tmoCntBC{$tmKey} {$recHrs} += 1;
  }

  if ( ($current_fld{SGA} eq "1V") || ($current_fld{SGA} eq "1C") ||
       ($current_fld{SGA} eq "1G") ) {
    $sga = "UA";
  }
  else {
    $sga = $current_fld{SGA};
  }

  $ln =~ /Context timeout: (\d+\/\d+\/\d+ \d+:\d+:\d+) /;
  $tmoMsgHash{$msn}[$ORGT] = $1;
  $tmoMsgHash{$msn}[$MSN] = $msn;
  $tmoMsgHash{$msn}[$GDS] = $current_fld{GDS};
  $tmoMsgHash{$msn}[$SGA] = $sga;
  $tmoMsgHash{$msn}[$MSGT] = $current_fld{MTP};

  # tally up the SGA's
  $sgaNumbersHash{$sga}[$TMO] += 1;
  $tmoSGAByTime{$tmKey}{$sga} += 1;
}

#####################################################################
## Do the not found in context searches through rtlog
##
#####################################################################
sub do_not_found() {

  # Now find when the message was finally recieved.
  # [USWPRODCE08] <= 09/27/12 02:00:24 (WY-A2) EX(A3IPCTXE): 
  # Cannot find USW message number 1606063B31552D in context. =>

  # [USWPRODCE13] <= 12/05/14 15:49:28 (MCW-A2) EX(A3IPCTXE): 
  # Cannot find USW message number 1402481D3F96F0 in context. =>

  @flds = split /\s/, $ln;

  if ($ln =~ /message number (\w+) /) {
    $msn = $1;
  }
  if ($ln =~ /<= (\d+\/\d+\/\d+ \d+:\d+:\d+) /) {
    $arivTime = $1;
  }
  $tmoMsgHash{$msn}[$ARVT] = $arivTime;
}

#####################################################################
## Zip and email the csv file that is produced.
##
#####################################################################
sub zip_email() {

  $mailer = "/bin/mailx";
  $zipper = "/usr/bin/zip";
  $sub = "Time Out and Dest Busy report for $inputChn";
  $zipfile = "${zipResultsName}.zip";

  #qx($zipper $zipfile $xlResultsName);

  qx($mailer -s "$sub" -a $xlResultsName $emails < ~/messages.txt);
  print "finished and mailed $xlResultsName to $emails. \n";

}

sub add_xls_headers {

  # Add a worksheet
  $graphs = $workbook->add_worksheet("Summary");

  # Set the formatting
  $global_format = $workbook->add_format();
  $global_format->set_color('black');
  $global_format->set_font('Ariel');
  $global_format->set_size(10);
  $global_format->set_align('left');
  $string_format = $workbook->add_format();
  $string_format->copy($global_format);
  $number_format = $workbook->add_format();
  $number_format->set_align('right');
  $number_format->set_num_format('###,##0');
                                                
  $graphs->set_column('A:A', 27);
  $graphs->set_column('B:B', 14);
  $graphs->set_column('C:E', 11);

  # Setup the headers in each worksheet
  if ($atLeastOneTO) {
    $timeOuts = $workbook->add_worksheet("Time Outs");
    $timeOuts->set_column('A:A', 17);
    $timeOuts->set_column('B:E', 13);
    $timeOuts->set_column('F:G', 18);
    $timeOuts->set_column('H:H', 23);
    $timeOuts->write('A1',"Message Number", $string_format);
    $timeOuts->write('B1',"GDS(ARS)", $string_format);
    $timeOuts->write('C1',"SGA", $string_format);
    $timeOuts->write('D1',"HRS(CHN)", $string_format);
    $timeOuts->write('E1',"Message Type", $string_format);
    $timeOuts->write('F1',"Origination time", $string_format);
    $timeOuts->write('G1',"HRS response time", $string_format);
    $timeOuts->write('H1',"HRS dwell time in seconds", $string_format);                                
  }

## Commenting out writing of the DSTB tab for now.
#  if ($atLeastOneDB) {
#    $destBusys = $workbook->add_worksheet("Destinations Busy");
#    $destBusys->set_column('A:A', 17);
#    $destBusys->set_column('B:E', 13);
#    $destBusys->set_column('F:F', 18);
#    $destBusys->write('A1',"Message Number", $string_format);                
#    $destBusys->write('B1',"GDS(ARS)", $string_format); 
#    $destBusys->write('C1',"SGA", $string_format);
#    $destBusys->write('D1',"HRS(CHN)", $string_format);
#    $destBusys->write('E1',"Message Type", $string_format);
#    $destBusys->write('F1',"Origination time", $string_format);
#  }

}

#####################################
##  Subroutine:  fillInTabs        ##
#####################################
sub fillInTabs {

  #  Sorting and ordering
  foreach $key (keys %sgaNumbersHash) {
    my $sga = $key;
    my $tmNm = $sgaNumbersHash{$key}[$TMO];
    my $dbNm = $sgaNumbersHash{$key}[$DSTB];
    my $dnNm = $sgaNumbersHash{$key}[$DSDN];

    if ($tmNm) {
      $key_num = 10000000000 + $tmNm;
      $new_key = $key_num . "_" . $sga;
      $new_val = $sga . "_" . $tmNm;
      $sgaTMOHashSorted{$new_key} = $new_val;
    }

    if ($dbNm) {
      $key_num = 10000000000 + $dbNm;
      $new_key = $key_num . "_" . $sga;
      $new_val = $sga . "_" . $dbNm;
      $sgaDSTBHashSorted{$new_key} = $new_val;
    }

    if ($dnNm) {
      $key_num = 10000000000 + $dnNm;
      $new_key = $key_num . "_" . $sga;
      $new_val = $sga . "_" . $dnNm;
      $sgaDSDNHashSorted{$new_key} = $new_val;
    }
  }

  # Put main hash in chronological order
  foreach $elem (sort keys %dstbMsgHash) {
    $new_key = $dstbMsgHash{$elem}[$ORGT] . $elem;
    $dstbMsgHByDate{$new_key} = $elem;
  }

  foreach $elem (sort keys %dsdnMsgHash) {
    $new_key = $dsdnMsgHash{$elem}[$ORGT] . $elem;
    $dsdnMsgHByDate{$new_key} = $elem;
  }

  foreach $elem (sort keys %tmoMsgHash) {
    $new_key = $tmoMsgHash{$elem}[$ORGT] . $elem;
    $tmoMsgHByDate{$new_key} = $elem;
  }

  # Put CHN hash in order by number of TO/DB
  foreach $key (keys %chnTOHash) {
    $key_num = 10000000000 + $chnTOHash{$key} + $chnDBHash{$key};
    $new_key = $key_num . "_" . $key;
    $new_val = $key . "_" . $chnTOHash{$key} . "_" . $chnDBHash{$key};
    $chnTOHashSorted{$new_key} = $new_val;
  }
  foreach $key (keys %chnDBHash) {
    $key_num = 10000000000 + $chnTOHash{$key} + $chnDBHash{$key};
    $new_key = $key_num . "_" . $key;
    $new_val = $key . "_" . $chnTOHash{$key} . "_" . $chnDBHash{$key};
    $chnTOHashSorted{$new_key} = $new_val;
  }

  $row = 2;     # Keep track of row and column                                  
  $col = 0;     # Keep track of row and column                                  
  $mnr = "message not returned";                                                                                                                                
  # Fill in TMO sheet
  foreach $elem (sort keys %tmoMsgHByDate) {                                      
    $msn = $tmoMsgHByDate{$elem};                                                 
                                                                                
    next if ($tmoMsgHash{$msn}[$MSN] eq "");                                    
                                                                                
    if ($tmoMsgHash{$msn}[$MSGT] eq "PALS") {                                   
      $tmoPals += 1;                                                            
    }                                                                           
    if ($tmoMsgHash{$msn}[$MSGT] eq "AALS") {                                   
      $tmoAals += 1;                                                            
    }                                                                           
    if ($tmoMsgHash{$msn}[$MSGT] eq "RPIN") {                                   
      $tmoRpin += 1;                                                            
    }                                                                           
    if ($tmoMsgHash{$msn}[$MSGT] eq "BOOK") {                                   
      $tmoBook += 1;                                                            
    }                                                                           
    $tmoTotal += 1;                                                             
    $chnTOHash{$tmoMsgHash{$msn}[$CHN]} += 1;                                   
                                                
    $timeOuts->write_string($row, $col++, $msn, $string_format);    
    $timeOuts->write($row, $col++, $tmoMsgHash{$msn}[$GDS], $string_format);    
    $timeOuts->write_string($row, $col++, $tmoMsgHash{$msn}[$SGA], $string_format);    
    $timeOuts->write($row, $col++, $tmoMsgHash{$msn}[$CHN], $string_format);    
    $timeOuts->write($row, $col++, $tmoMsgHash{$msn}[$MSGT], $string_format);   
    $timeOuts->write($row, $col++, $tmoMsgHash{$msn}[$ORGT], $string_format);   
                                                                                
    if ($tmoMsgHash{$msn}[$ARVT]) {                                             
                                                                                
      # Calculate the total message time in seconds by converting ORGT          
      # and ARVT to UTC and subtracting ORGT from ARVT                          
      # Fomat of both:  "07/08/13 05:42:41"                                     
      ($mdy, $hms) = split /\s/, $tmoMsgHash{$msn}[$ORGT];                      
      ($mon, $mday, $year) = split /\//, $mdy;                                  
      $mon -= 1;                                                                
      ($hours, $min, $sec) = split /:/, $hms;                                   
                                                                                
      if ($mday > 1 && $mday < 31) {                                            
        $org_time_utc = timegm($sec, $min, $hours, $mday, $mon, $year);         
      }                                                                         
      else {                                                                    
        $org_time_utc = 0;                                                      
      }

      ($mdy, $hms) = split /\s/, $tmoMsgHash{$msn}[$ARVT];                      
      ($mon, $mday, $year) = split /\//, $mdy;                                  
      $mon -= 1;                                                                
      ($hours, $min, $sec) = split /:/, $hms;                                   
      if ($mday > 1 && $mday < 31) {                                            
        $arv_time_utc = timegm($sec, $min, $hours, $mday, $mon, $year);         
      }                                                                         
      else {                                                                    
        $arv_time_utc = 0;                                                      
      }                                                                         
                                                                                
      if ($org_time_utc != 0 && $arv_time_utc != 0) {                           
        $diff_time = $arv_time_utc - $org_time_utc;                             
        $timeOuts->write($row, $col++, $tmoMsgHash{$msn}[$ARVT],                
                         $string_format);                                       
        $timeOuts->write($row, $col++, $diff_time, $number_format);             
      }                                                                         
      else {                                                                    
        $timeOuts->write($row, $col++, $mnr, $string_format);                   
        $timeOuts->write($row, $col++, "0", $number_format);                    
        $tmoNoAns += 1;                                                         
        print "Element $msn had a bad date \n";                                 
      }                                                                         
    }                                                                           
    else {                                                                      
      $timeOuts->write($row, $col++, $mnr, $string_format);                     
      $timeOuts->write($row, $col++, "0", $number_format);                      
      $tmoNoAns += 1;                                                           
    }                                                                           
    $row++;                                                                     
    $col = 0;                                                                   
  }                                                                             

  $row = 2;
  $col = 0;
                                                                                
  # Fill in Dest Busy sheet
  foreach $elem (sort keys %dstbMsgHByDate) {                                   
    $msn = $dstbMsgHByDate{$elem};                                              
                                                                                
    if ($dstbMsgHash{$msn}[$MSGT] eq "PALS") {                                  
      $dstbPals += 1;                                                           
    }                                                                           
    if ($dstbMsgHash{$msn}[$MSGT] eq "AALS") {                                  
      $dstbAals += 1;                                                           
    }                                                                           
    if ($dstbMsgHash{$msn}[$MSGT] eq "RPIN") {                                  
      $dstbRpin += 1;                                                           
    }                                                                           
    if ($dstbMsgHash{$msn}[$MSGT] eq "BOOK") {                                  
      $dstbBook += 1;                                                           
    }                                                                           
    $dstbTotal += 1;                                                            
    $chnDBHash{$dstbMsgHash{$msn}[$CHN]} += 1;                                  
                                                                                
    #$destBusys->write($row, $col++, $dstbMsgHash{$msn}[$MSN], $string_format);  
    #$destBusys->write($row, $col++, $dstbMsgHash{$msn}[$GDS], $string_format);  
    #$destBusys->write($row, $col++, $dstbMsgHash{$msn}[$SGA], $string_format);  
    #$destBusys->write($row, $col++, $dstbMsgHash{$msn}[$CHN], $string_format);  
    #$destBusys->write($row, $col++, $dstbMsgHash{$msn}[$MSGT], $string_format); 
    #$destBusys->write($row, $col++, $dstbMsgHash{$msn}[$ORGT], $string_format); 
    $row++;                                                                     
    $col = 0;                                                                   
  }     
                                                    
  # Fill in Dest Busy sheet
  foreach $elem (sort keys %dsdnMsgHByDate) {                                   
    $msn = $dsdnMsgHByDate{$elem};                                              
                                                                                
    if ($dsdnMsgHash{$msn}[$MSGT] eq "PALS") {                                  
      $dsdnPals += 1;                                                           
    }                                                                           
    if ($dsdnMsgHash{$msn}[$MSGT] eq "AALS") {                                  
      $dsdnAals += 1;                                                           
    }                                                                           
    if ($dsdnMsgHash{$msn}[$MSGT] eq "RPIN") {                                  
      $dsdnRpin += 1;                                                           
    }                                                                           
    if ($dsdnMsgHash{$msn}[$MSGT] eq "BOOK") {                                  
      $dsdnBook += 1;                                                           
    }                                                                           
    $dsdnTotal += 1;                                                            
    $chnDBHash{$dsdnMsgHash{$msn}[$CHN]} += 1;                                  
  }     

  if ($cmd_day) {
    $startTime = timegm(0,0,0, $cmd_day, $curMonth, $curYear);
    $stopTime = $startTime + 86400;
  }
  else {
    # set mmddyy for today for start of day
    ($tday, $tmon, $tyear) = (gmtime)[3,4,5];
    $startTime = timegm(0,0,0, $tday, $tmon, $tyear);
    $stopTime = $startTime + 86400;
  } 

  # Setup the counts tab in the workbook
  if ($atLeastOneTO) {

    $tmCounts = $workbook->add_worksheet("TOcounts");
    $tmCounts->write_string('A1', "Time", $string_format);
    $tmCounts->write_string('A2', "SGA", $string_format);
    $tmCounts->write_string('C1', "Counts", $string_format);

    $toColNum = $toRowNum = 1;
    foreach $key (reverse sort keys %sgaTMOHashSorted) {
      ($sga, $sgaCnt) = split /_/, $sgaTMOHashSorted{$key};
      $tmCounts->write_string($toRowNum, $toColNum++, $sga, $string_format);
    }
    $toRowNum++;
  }

  if ($atLeastOneDB) {

    $dbCounts = $workbook->add_worksheet("DBcounts");
    $dbCounts->write('A1', "Time", $string_format);
    $dbCounts->write('A2', "SGA", $string_format);
    $dbCounts->write('C1', "Counts", $string_format);

    $dbColNum = $dbRowNum = 1;
    foreach $key (reverse sort keys %sgaDSTBHashSorted) {
      ($sga, $sgaCnt) = split /_/, $sgaDSTBHashSorted{$key};
      $dbCounts->write_string($dbRowNum, $dbColNum++, $sga, $string_format);
    }
    $dbRowNum++;
  }

  if ($atLeastOneDN) {

    $dnCounts = $workbook->add_worksheet("DNcounts");
    $dnCounts->write('A1', "Time", $string_format);
    $dnCounts->write('A2', "SGA", $string_format);
    $dnCounts->write('C1', "Counts", $string_format);

    $dnColNum = $dnRowNum = 1;
    foreach $key (reverse sort keys %sgaDSDNHashSorted) {
      ($sga, $sgaCnt) = split /_/, $sgaDSDNHashSorted{$key};
      $dnCounts->write_string($dnRowNum, $dnColNum++, $sga, $string_format);
    }
    $dnRowNum++;
  }

  # For each minute in the day, put in TM or DB info
  for ($curTime = $startTime; $curTime < $stopTime; $curTime += 60) {

    ($sec, $min, $hrs, $dom, $mon, $year, $wd, $yd, $isd) = gmtime($curTime);
    $tmoCntTime = sprintf "%02d:%02d", $hrs, $min;

    # Put in the Timeout Info
    if ($atLeastOneTO) {

      my %locTm = %{$tmoSGAByTime{$curTime}};
      $toColNum = 0; 
      $tmCounts->write($toRowNum, $toColNum++, $tmoCntTime, $string_format);
      foreach $key (reverse sort keys %sgaTMOHashSorted) {
	($sga, $sgaCnt) = split /_/, $sgaTMOHashSorted{$key};
	$tmCounts->write($toRowNum, $toColNum++, $locTm{$sga} || '0', $number_format);
      }
      $toRowNum++;
    }
    
    # Put in the Dest Busy Info
    if ($atLeastOneDB) {

      my %locDb = %{$dstbSGAByTime{$curTime}};
      $dbColNum = 0;
      $dbCounts->write($dbRowNum, $dbColNum++, $tmoCntTime, $string_format);
      foreach $key (reverse sort keys %sgaDSTBHashSorted) {
	($sga, $sgaCnt) = split /_/, $sgaDSTBHashSorted{$key};
	$dbCounts->write($dbRowNum, $dbColNum++, $locDb{$sga} || '0', $number_format);
      }
      $dbRowNum++;
    }
   
    # Put in the Dest Down Info
    if ($atLeastOneDN) {

      my %locDn = %{$dsdnSGAByTime{$curTime}};
      $dnColNum = 0;
      $dnCounts->write($dnRowNum, $dnColNum++, $tmoCntTime, $string_format);
      foreach $key (reverse sort keys %sgaDSDNHashSorted) {
	($sga, $sgaCnt) = split /_/, $sgaDSDNHashSorted{$key};
	$dnCounts->write($dnRowNum, $dnColNum++, $locDn{$sga} || '0', $number_format);
      }
      $dnRowNum++;
    }
  }  
}


#####################################
##  Subroutine:  doSummary        ##
#####################################
sub doSummary {

  $row = 0;
  $col = 0;

  $graphs->write($row, $col++, "TOTALS", $string_format);
  $graphs->write($row, $col++, "Timeouts", $string_format);
  $graphs->write($row, $col++, "Dest Busy", $string_format);
  $graphs->write($row++, $col++, "Dest Down", $string_format);
  $col = 0;

  $graphs->write($row, $col++, "PALS messages", $string_format);
  $graphs->write($row, $col++, $tmoPals, $number_format);
  $graphs->write($row, $col++, $dstbPals, $number_format);
  $graphs->write($row++, $col, $dsdnPals, $number_format);
  $col = 0;

  $graphs->write($row, $col++, "AALS messages", $string_format);
  $graphs->write($row, $col++, $tmoAals, $number_format);
  $graphs->write($row, $col++, $dstbAals, $number_format);
  $graphs->write($row++, $col, $dsdnAals, $number_format);
  $col = 0;

  $graphs->write($row, $col++, "RPIN messages", $string_format);
  $graphs->write($row, $col++, $tmoRpin, $number_format);
  $graphs->write($row, $col++, $dstbRpin, $number_format);
  $graphs->write($row++, $col, $dsdnRpin, $number_format);
  $col = 0;

  $graphs->write($row, $col++, "BOOK messages", $string_format);
  $graphs->write($row, $col++, $tmoBook, $number_format);
  $graphs->write($row, $col++, $dstbBook, $number_format);
  $graphs->write($row++, $col, $dsdnBook, $number_format);
  $col = 0;

  $graphs->write($row, $col++, "Total messages", $string_format);
  $graphs->write($row, $col++, $tmoTotal, $number_format);
  $graphs->write($row, $col++, $dstbTotal, $number_format);
  $graphs->write($row++, $col, $dsdnTotal, $number_format);
  $col = 0;

  $graphs->write($row, $col++, "Total messages with no answer", 
                 $string_format);
  $graphs->write($row, $col++, $tmoNoAns, $number_format);
  $graphs->write($row++, $col++, "0", $number_format);
  $col = 0;
  $row++;

  #print Dumper (\%sgaNameHash);
  # Write SGA TMO hash 
  # Write $smallLimit or less if there are less, nothing if zero
  $hcnt = keys %sgaTMOHashSorted;
  if ($hcnt < $smallLimit) {
    $hlimit = $hcnt;
  }     
  else {
    $hlimit = $smallLimit;
  }

  # Check hlimit in case it's zero
  if ($hlimit) {
    $col = 0;
    $graphs->write($row, $col++, "SGA", $string_format);
    $graphs->write($row, $col++, "SGA Name", $string_format);
    $graphs->write($row++, $col++, "Timeouts", $string_format);
    $col = $y = 0;
    foreach $key (reverse sort keys %sgaTMOHashSorted) {
      my ($sga, $tmo) = split /_/, $sgaTMOHashSorted{$key};
      if ($y < $hlimit) {
	$graphs->write_string($row, $col++, $sga, $string_format);
	$graphs->write($row, $col++, $sgaNameHash{$sga}, $string_format);
	$graphs->write($row++, $col++, $tmo, $number_format);
	$col = 0;
	$y++;
      }
    }
    $row++;
  }

  # Write SGA DSTB hash 
  # Write $bigLimit or less if there are less, nothing if zero
  $hcnt = keys %sgaDSTBHashSorted;
  if ($hcnt < $bigLimit) {
    $hlimit = $hcnt;
  }     
  else {
    $hlimit = $bigLimit;
  }

  if ($hlimit) {
    $col = 0;
    $graphs->write($row, $col++, "SGA", $string_format);
    $graphs->write($row, $col++, "SGA Name", $string_format);
    $graphs->write($row++, $col++, "Dest Busy", $string_format);
    $col = $y = 0;
    foreach $key (reverse sort keys %sgaDSTBHashSorted) {
      my ($sga, $dstb) = split /_/, $sgaDSTBHashSorted{$key};
      if ($y < $hlimit) {
	$graphs->write_string($row, $col++, $sga, $string_format);
	$graphs->write($row, $col++, $sgaNameHash{$sga}, $string_format);
	$graphs->write($row++, $col, $dstb, $number_format);
	$col = 0;
	$y++;
      }
    }
    $row++;
  }

  # Write SGA DSDN hash 
  # Write $smallLimit or less if there are less, nothing if zero
  $hcnt = keys %sgaDSDNHashSorted;
  if ($hcnt < $smallLimit) {
    $hlimit = $hcnt;
  }     
  else {
    $hlimit = $smallLimit;
  }

  if ($hlimit) {
    $col = 0;
    $graphs->write($row, $col++, "SGA", $string_format);
    $graphs->write($row, $col++, "SGA Name", $string_format);
    $graphs->write($row++, $col, "Dest Denied", $string_format);
    $col = $y = 0;
    foreach $key (reverse sort keys %sgaDSDNHashSorted) {
      my ($sga, $dsdn) = split /_/, $sgaDSDNHashSorted{$key};
      if ($y < $hlimit) {
	$graphs->write_string($row, $col++, $sga, $string_format);
	$graphs->write($row, $col++, $sgaNameHash{$sga}, $string_format);
	$graphs->write($row++, $col, $dsdn, $number_format);
	$col = 0;
	$y++;
      }
    }
    $y = 0;
    $col = 0;
    $row++;
  }
}

#####################################
##  Subroutine:  doCharts        ##
#####################################
sub doCharts {
  
  $colP = "E";
  $rowP = 2;

  # MIKEW
  if ($atLeastOneTO) {

    # Create a new chart object. In this case an embedded chart.
    my $tmchart = $workbook->add_chart( type => 'line', embedded => 1 );
    $toColStart = $toColEnd = $chartmem = 1;
    foreach $key (reverse sort keys %sgaTMOHashSorted) {
      my ($sga, $tmonum) = split /_/, $sgaTMOHashSorted{$key};
      if ($chartmem < 10) {
	$tmchart->add_series(
	  name       => "$sga TMO",
	  categories => [ 'TOcounts', 2, $toRowNum, 0, 0 ],
	  values     => [ 'TOcounts', 2, $toRowNum, $toColStart++, $toColEnd++],
	);
	$chartmem++;
      }
    }

    # Add a chart title and some axis labels.
    $tmchart->set_title ( name => 'Timeout Counts by minute' );
    $tmchart->set_x_axis( name => 'Time GMT' );
    $tmchart->set_y_axis( name => 'Count' );
    $tmchart->set_size( width => 1200, height => 500);

    # Set an Excel chart style. Colors with white outline and shadow.
    $tmchart->set_style( 10 );

    # Insert the chart into the worksheet (with an offset).
    $place = sprintf "%s%d", $colP, $rowP;
    $graphs->insert_chart( "$place", $tmchart, 10, 0 );
    $rowP += 27;
  }

  if ($atLeastOneDB) {
    # Create a new chart object. In this case an embedded chart.
    my $dbchart = $workbook->add_chart( type => 'line', embedded => 1 );
    # Foreach SGA, add another series
    $dbColStart = $dbColEnd = $chartmem = 1;
    foreach $key (reverse sort keys %sgaDSTBHashSorted) {
      my ($sga, $dstb) = split /_/, $sgaDSTBHashSorted{$key};
      if ($chartmem < 10) {
	$dbchart->add_series(
	  name       => "$sga DB",
	  categories => [ 'DBcounts', 2, $dbRowNum, 0, 0 ],
	  values     => [ 'DBcounts', 2, $dbRowNum, $dbColStart++, $dbColEnd++],
	);
	$chartmem++;
      }
    }
 
    # Add a chart title and some axis labels.
    $dbchart->set_title ( name => 'Destination Busy Counts by minute' );
    $dbchart->set_x_axis( name => 'Time GMT' );
    $dbchart->set_y_axis( name => 'Count' );
    $dbchart->set_size( width => 1200, height => 500);
  
    # Set an Excel chart style. Colors with white outline and shadow.
    $dbchart->set_style( 10 );

    # Insert the chart into the worksheet (with an offset).
    $place = sprintf "%s%d", $colP, $rowP;
    $graphs->insert_chart( "$place", $dbchart, 10, 0 );
    $rowP += 27;
  }

  if ($atLeastOneDN) {
    # Create a new chart object. In this case an embedded chart.
    my $dnchart = $workbook->add_chart( type => 'line', embedded => 1 );
    # Foreach SGA, add another series
    $dnColStart = $dnColEnd = $chartmem = 1;
    # MIKEW
    foreach $key (reverse sort keys %sgaDSDNHashSorted) {
      my ($sga, $dsdn) = split /_/, $sgaDSDNHashSorted{$key};
      if ($chartmem < 10) {
	$dnchart->add_series(
	  name       => "$sga DN",
	  categories => [ 'DNcounts', 2, $dnRowNum, 0, 0 ],
	  values     => [ 'DNcounts', 2, $dnRowNum, $dnColStart++, $dnColEnd++],
	);
	$chartmem++;
      }
    }
 
    # Add a chart title and some axis labels.
    $dnchart->set_title ( name => 'Destination Down Counts by minute' );
    $dnchart->set_x_axis( name => 'Time GMT' );
    $dnchart->set_y_axis( name => 'Count' );
    $dnchart->set_size( width => 1200, height => 500);
  
    # Set an Excel chart style. Colors with white outline and shadow.
    $dnchart->set_style( 10 );

    # Insert the chart into the worksheet (with an offset).
    $place = sprintf "%s%d", $colP, $rowP;
    $graphs->insert_chart( "$place", $dnchart, 10, 0 );
  }
}

sub populateSgaNames {

  open IFP, "< $sgaInputFile";
  
  while (<IFP>) {
    chomp;
    ($sga, $comp) = split /=/;
    $sgaNameHash{$sga} = "$comp";
  }
  close IFP;
} 

