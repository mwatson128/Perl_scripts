#!/usr/local/bin/perl

use Getopt::Long;
use Time::Local;

sub usage();
sub cmdline();
sub do_init();
sub do_context_to();
sub do_not_found();
sub do_stats_look();
sub hash_reorder();
sub print_data();
sub print_totals();
sub print_sgas();
sub zip_email();

#####################################################################
## Initialize variables
##
#####################################################################

$help_cmd = 0;
$rm_all = 0;
$y = 0;

$MSN = 0;
$GDS = 1;
$SGA = 2;
$CHN = 3;
$MSGT = 4;
$ORGT = 5;
$ARVT = 6;
$DIFF = 7;

$total_pals = 0;
$total_aals = 0;
$total_rpin = 0;
$total_book = 0;
$total_all = 0;
$monday = "";

############
##  Main  ##
############

# call command line parsing funciton
cmdline();

# Initialize/load variables and default values
do_init();

foreach $ln (@file_cont) {
  chomp $ln;

  # Get time from record
  if ($ln =~ (/(\d\d)\/(\d\d)\/(\d\d) (\d\d):(\d\d):\d\d/)) {
    $rec_time = timegm($6,$5,$4,$2,($1 - 1),($3 + 2000));
  }
  # cutoff_time calculated in do_init
  if (($start_time_utc > $rec_time) || ($end_time_utc < $rec_time)) {
    next;
  }

  if ($ln =~ /Context timeout/) {
    do_context_to();
  }

  if ($ln =~ /Cannot find USW message/) {
    do_not_found();
  }

}

# Now match MSN's with stats
do_stats_look();

# Reorder the hashes
hash_reorder();

# Open the file and write the header info
if ($chn) {
  
  if ($chn =~ m/,/) {
    @chns = split (/,/, $chn);
    $fname = join("_", @chns, "");
  }
  else {
    $fname = $chn;
  }

  $ofp_name = "${fname}_timeouts_${monday}_${file_day_end}.csv";
}
else {
  $ofp_name = "all_timeouts_${monday}_${file_day_end}.csv";
}
open OFP, "> $ofp_name";
  
printf OFP "Message number, GDS(ARS), SGA, HRS(CHN), Message Type, Origination time, HRS response time, HRS dwell time in seconds";

# Print the raw data to the output file
print_data();

printf OFP "\n\n";
 
# print totals to the output file
print_totals();

# Print top 10 sga's. 
print_sgas();

close OFP;
print "output is in $ofp_name \n";

zip_email();

#`rm $tmpfile`;

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
    'c|chn=s' => \$chn,
    'h|help' => \$help_cmd,
    'f|file=s' => \$filename,
    'r|rtdir=s' => \$user_rtdir,
    'd|day=s' => \$cmd_day,
    'e|email=s' => \$email_add,
    'a|all' => \$unfilter,
  );

  # Use current time to get variables
  ($s, $m, $ch, $md, $mo, $y, $wd, $yd, $isdst) = gmtime();
  $gy = $y + 1900;
  $gmo = $mo + 1;
  
  # Get the time now and put in variable for later.
  $time_now = timegm($s, $m, $ch, $md, $mo, $y);
  
  # Set output file extension based on current time vars
  $file_day_end = $gmo . "_" . $md . "_" . $ch . "_" . $m;
  print "Time now = $time_now and File dayend is $file_day_end \n";
  
  # Load stats files array
  push (@statsfiles, "uswota-stats.log");
  $sfile = sprintf "uswota-stats.log.%d-%02d-%02d-%02d", $gy, $gmo, $md, $ch;
  push (@statsfiles, $sfile);

  # Use our hour ago to get vars
  $lasthour = $time_now - 3600;
  ($s, $m, $ch, $md, $mo, $y, $wd, $yd, $isdst) = gmtime($lasthour);
  $gy2 = $y + 1900;
  $gmo2 = $mo + 1;
  $sfile = sprintf "uswota-stats.log.%d-%02d-%02d-%02d", $gy2, $gmo2, $md, $ch;
  push (@statsfiles, $sfile);

  # Make up start_time_utc and end_time_utc
  # Go back 10 minutes
  $start_time_utc = $time_now - 1200;
  # End at current time.
  $end_time_utc = $time_now;

  $zone = `uname -n`;
  chomp($zone);

  if ($email_add) {
    #$emails = "pedpg\@pegs.com $email_add"; 
    $emails = "mike.watson\@pegs.com $email_add"; 
  }
  else {
    #$emails = "pedpg\@pegs.com";
    $emails = "mike.watson\@pegs.com"; 
  }

  if ($help_cmd == 1) {
    usage();
    exit();
  }
  elsif ($chn eq "" && $unfilter != 1) {
    usage();
    exit();
  }
}

#####################################################################
## Usage printing function
##
#####################################################################
sub usage() {

  print "Usage: tm_stats_trace.pl <options> -c is required\n";
  print "  Will find CHN's timeouts in the current rtlog and stats log \n";
  print "  and print the information found in comma separated form to be \n";
  print "  sent to the customer. \n";
  print "  Options:\n";
  print "  -(h|help)           - Print this help message \n";
  print "  -(c|chn) CHN        - any USW chain code. \n";
  print "  -(e|email) email@pegs.com - send to this email also.\n";
  print "  -(f|file) rtlogfile - file to use instead of regular rtlog\n";
  print "  -(r|rtdir) log dir  - directory to use instead of regular dir\n";

}

#####################################################################
## Initialize variables and load in default values.
##
#####################################################################
sub do_init() {

  # define filename
  if ($filename eq "" && $cmd_day eq "") {
    $day = `date -u '+%d'`;
    chomp($day);
    # will convert day to int, dropping leading zero
    $day += 0;
    $filename = "rtlog" . $day;
    $monday = `date -u '+%m%d'`;
    chomp($monday);
  }
  if ($filename eq "" && $cmd_day ne "") {
    $mon = `date -u '+%m'`;
    chomp $mon;
    $curday = `date -u '+%d'`;
    # If the day asked for is greater than today, take one from month
    if ($cmd_day > $curday) {
      $mon -= 1;
    }
    $monday = $mon . $cmd_day;
    $monday = sprintf "%02d%02d", $mon, $cmd_day;

    # will convert day to int, dropping leading zero
    $cmd_day += 0;
    $filename = "rtlog" . $cmd_day;
  }

  # Using the LOGNAME env variable to set default values
  if ($ENV{LOGNAME} =~ /^usw$|^prod_sup$|^sun1$/) {
    #$rtdir = "/$zone/logs/rtlogs/";
    $rtdir = "/pegs/logs/$zone/rtlogs/";

  }
  elsif ($ENV{LOGNAME} eq "uswrpt") {
    $mony = `date -u '+%m%y'`;
    chomp $mony;
    $supdir = "/$zone/loghist/uswprod01/rtlogs/" . $mony;
    qx(cp ${supdir}/${filename}* .);
    qx(gunzip $filename);
    $rtdir = "./";
    $rm_all = 1;
  }
  else {
    $rtdir = "./";
  }

  if (defined $user_rtdir) {
    $rtdir = $user_rtdir . "/";
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
  if ($chn) {
    $tmpfile = "${chn}_rtfile";
    if ($chn =~ m/,/) {
      @chns = split (/,/, $chn);
      foreach $part (@chns) {
        $chain_grep .= $part . "-A2|";
        $v_grep .= "H" . $part . "-A2|";
        $v_grep .= "G" . $part . "-A2|";
      }
      $chain_grep = substr($chain_grep, 0, -1);
      $v_grep = substr($v_grep, 0, -1);
      `egrep "$chain_grep" ${rtdir}${filename} | egrep -v "$v_grep" > $tmpfile`;
    }
    else {
      $chain_grep = $chn . "-A2";
      $v_grep .= "H" . $chn . "-A2|";
      $v_grep .= "G" . $chn . "-A2|";
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

  @file_cont = `cat $tmpfile`;
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
  $msn = $current_fld{msgno};

  # Context timeout looks like:
  # [USWPRODCE08] <= 09/27/12 02:00:05 (WY-A2) EX(A3IPCTTM): 
  # Context timeout: 09/27/12 01:59:50 HRS:WY  GDS:WB  SGA:S1 
  # msgno:1606063B31552D MTP:PALS =>

  if ($chn =~ m/,/) {
    $msg_hash{$msn}[$CHN] = $current_fld{HRS};
  }
  elsif ($chn != "") {
    if ($chn eq $current_fld{HRS}) {
      $msg_hash{$msn}[$CHN] = $chn;
    }
  }
  else {
    $msg_hash{$msn}[$CHN] = $current_fld{HRS};
  }

  $sga = $current_fld{SGA};

  $orgtime = $flds[7] . " " . $flds[8];
  $msg_hash{$msn}[$MSN] = $msn;
  $msg_hash{$msn}[$GDS] = $current_fld{GDS};
  $msg_hash{$msn}[$SGA] = $sga;
  $msg_hash{$msn}[$MSGT] = $current_fld{MTP};
  $msg_hash{$msn}[$ORGT] = $orgtime;

  # tally up the SGA's
  $sga_hash{$sga} += 1;
}

#####################################################################
## Do the not found in context searches through rtlog
##
#####################################################################
sub do_not_found() {

  # Now find when the message was finally recieved.
  # [USWPRODCE08] <= 09/27/12 02:00:24 (WY-A2) EX(A3IPCTXE): 
  # Cannot find USW message number 1606063B31552D in context. =>

  @flds = split /\s/, $ln;
  $msn = $flds[11];

  # Get HRS from 4th field (WY-A2)
  @parts = split /-/, $flds[4];
  @l = split //, $parts[0];
  shift @l;
  $hrs = join ("", @l);

  $arvtime = $flds[2] . " " . $flds[3];
  $msg_hash{$msn}[$ARVT] = $arvtime;
}

#####################################################################
## Reorder the hashes so they are orderd correctly for printing.
##
#####################################################################
sub hash_reorder() {

  # Now put top 10 sga's in numerical order
  foreach $key (keys %sga_hash) {
    $key_num = 10000000000 + $sga_hash{$key};
    $new_key = $key_num . "_" . $key;
    $new_val = $key . "_" . $sga_hash{$key};
    $sga_hash_sorted{$new_key} = $new_val;
  }

  # Put main hash in chronological order
  foreach $elem (sort keys %msg_hash) {
    $new_key = $msg_hash{$elem}[$ORGT] . $elem;
    $hash_bydate{$new_key}[$MSN] = $msg_hash{$elem}[$MSN];
    $hash_bydate{$new_key}[$GDS] = $msg_hash{$elem}[$GDS];
    $hash_bydate{$new_key}[$SGA] = $msg_hash{$elem}[$SGA];
    $hash_bydate{$new_key}[$CHN] = $msg_hash{$elem}[$CHN];
    $hash_bydate{$new_key}[$MSGT] = $msg_hash{$elem}[$MSGT];
    $hash_bydate{$new_key}[$ORGT] = $msg_hash{$elem}[$ORGT];
    $hash_bydate{$new_key}[$ARVT] = $msg_hash{$elem}[$ARVT];

  }
}

#####################################################################
## Print the raw data to the file
##
#####################################################################
sub print_data() {


  foreach $word (@words_array) {
    printf OFP ", $word";
  }
  printf OFP "\n";

  foreach $elem (sort keys %hash_bydate) {

    next if ($hash_bydate{$elem}[$MSN] eq "");

    if ($hash_bydate{$elem}[$MSGT] eq "PALS") {
      $total_pals += 1;
    }
    if ($hash_bydate{$elem}[$MSGT] eq "AALS") {
      $total_aals += 1;
    }
    if ($hash_bydate{$elem}[$MSGT] eq "RPIN") {
      $total_rpin += 1;
    }
    if ($hash_bydate{$elem}[$MSGT] eq "BOOK") {
      $total_book += 1;
    }
    $total_all += 1;

    printf OFP "$hash_bydate{$elem}[$MSN],";
    printf OFP "$hash_bydate{$elem}[$GDS],";
    printf OFP "$hash_bydate{$elem}[$SGA],";
    printf OFP "$hash_bydate{$elem}[$CHN],";
    printf OFP "$hash_bydate{$elem}[$MSGT],";
    printf OFP "$hash_bydate{$elem}[$ORGT],";
    if ($hash_bydate{$elem}[$ARVT]) {  

      
      # Calculate the total message time in seconds by converting ORGT 
      # and ARVT to UTC and subtracting ORGT from ARVT
      # Fomat of both:  "07/08/13 05:42:41"
      ($mdy, $hms) = split /\s/, $hash_bydate{$elem}[$ORGT];
      ($mon, $mday, $year) = split /\//, $mdy;
      $mon -= 1;
      ($hours, $min, $sec) = split /:/, $hms;

      if ($mday > 1 && $mday < 31) {
        $org_time_utc = timegm($sec, $min, $hours, $mday, $mon, $year);
      }
      else {
        $org_time_utc = 0;
      }
      
      ($mdy, $hms) = split /\s/, $hash_bydate{$elem}[$ARVT];
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
        printf OFP "$hash_bydate{$elem}[$ARVT],$diff_time";
      }
      else {
        printf OFP "message not returned, 0";
        $total_noan += 1;
        print "Element $elem had a bad date \n";
      }
    }
    else {
      printf OFP "message not returned, 0";
      $total_noan += 1;
    }

    foreach $word (@words_array) {
      $msn = $hash_bydate{$elem}[$MSN];
      #print "8: msn_key is $msn \n";
      #print "9: Word key is $word  = ";
      #print " $msn_stats{$msn}{$word} \n\n";
      printf OFP ",$msn_stats{$msn}{$word}";
    }

    printf OFP "\n";
  }
}

#####################################################################
## Print totals at the end of the file
##
#####################################################################
sub print_totals() {

  printf OFP "Total PALS messages timed out,$total_pals\n";
  printf OFP "Total AALS messages timed out,$total_aals\n";
  printf OFP "Total RPIN messages timed out,$total_rpin\n";
  printf OFP "Total BOOK messages timed out,$total_book\n";
  printf OFP "Total messages with no answer,$total_noan\n";
  printf OFP "Total timed out messages     ,$total_all\n\n";

}

#####################################################################
## Print SGA top talkers to the output file
##
#####################################################################
sub print_sgas() {

  printf OFP "Timeouts by SGA (top 10)\nSGA,Timeouts\n";
  foreach $key (reverse sort keys %sga_hash_sorted) {
    ($sga, $num_to) = split /_/, $sga_hash_sorted{$key};
    if ($y < 10) {
      printf OFP "$sga,$num_to\n";
      $y++;
    }
  }
  printf OFP "\n";
}

#####################################################################
## Zip and email the csv file that is produced.
##
#####################################################################
sub zip_email() {

  $mailer = "/usr/bin/mailx";

  $zipper = "/usr/bin/zip";
  $zipfile = "${ofp_name}.zip";

  qx($zipper $zipfile $ofp_name);
  
  qx(uuencode $zipfile $zipfile | $mailer -s "timeouts for ${chn}" $emails);

  print "finished and mailed $zipfile to $emails. \n";

}

sub do_stats_look() {

  # Now find the stats log message in uswota-stats.log
  # 2014-01-07 22:05:23.865 
    #[statsLogger.com.pegs.uswota.outbound.UswMessageListenerBean] 
    #[ INFO] [p: thread-pool-1; w: 66] [] [exec=onMessage] [status=0]
    #[jms.dwell=0]
    #[host=uswprodce13] [instance=d1c1_13]
    #[type=PALSRQ] [sga=R7] [gds=WB] [msn=160A2CC7A13334]
    #[hrs=RT] [pid=8772] [amf2genOTA.conv.time=2]
    #[hrs.endpoint=https://81.252.189.101/pegasus/OTAReceiver/PegsEntryPoint]
    #[xmlrequest.size=2490]
    #[request.time=4]
    #[hrs.time=16480]
    #[encoding=gzip]
    #[zipped.size=2506]
    #[conv2str.zip=150]
    #[xmlResponse.size=59887]
    #[pay2string=1]
    #[genOTA2amf.conv.time=15]
    #[sendResponse.conn=0] [sendResponse.destination=0]
    #[sendResponse.session=1] [sendResponse.createProducer=0]
    #[sendResponse.send=0] [sendResponse=1]
    #[response.time=172]
    #[exec.time=16656] 

  # Put each grep and each result in a file, then read in.
  # Putting many in one file makes for a large file.

  foreach $msn (keys %msg_hash) {
    next if ((length $msn) < 14);

    qx(echo ": \n" > grepfile_$msn);
    # Grep for MSG num in stats logs.

    $statsdir = "/pegs/logs/$zone/otadas*/d*/uswota/";
    foreach $sf (@statsfiles) {
      $sfile = $statsdir . $sf;
      qx(echo "grep $msn $sfile >> results_$msn" >> grepfile_$msn);
    }

    system "chmod 755 grepfile_$msn";
    system "grepfile_$msn";
    @stats_info = qx(cat results_$msn);

    foreach $ln (@stats_info) {
      $stats_info[0] =~ /msn=(\w+)/;
      $msn = $1;
      $ln =~ s/\[/ /g;
      $ln =~ s/\]/ /g;
      @just_words = split /\s+/, $ln;
      foreach $word (@just_words) {
	($key, $value) = split /=/, $word;
	if ($key && $value) {
	  $msn_stats{$msn}{$key} = $value;
	}
      }
    }

    # clean up...
    #qx(rm results1 grepfile1);
  }

  # Make up an array of keys for the words_hash
  @words_array = qw(amf2genOTA.conv.time conv2str.zip exec.time 
                    genOTA2amf.conv.time hrs.time jms.dwell 
		    pay2string pid request.time response.time 
		    sendResponse sendResponse.send xmlResponse.size 
		    xmlrequest.size zipped.size);
}


