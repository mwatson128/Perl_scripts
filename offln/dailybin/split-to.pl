#!/usr/local/bin/perl
# (]$[) split-to.pl:1.1 | CDATE=03/30/01 12:02:16
#######################################################################
# This script will E-mail a copy of the daily context timeouts report #
# and put the specified brands at the top of the list.                #
#######################################################################

#############################################################
# Parse Command line input for the date, and if its invalid #
# set it to yesterday                                       #
#############################################################
if ($ARGV[0] =~ /\d\d\/\d\d\/\d\d/) {
  $date = $ARGV[0];
} else {
  $date = `/usw/offln/bin/getydate -s`;
}
($month, $day, $year) = split /\//, $date;
$day = $day + 0;

########################################################
# Set other variables and also those based on the date #
########################################################
$mailconfig = "brand-sort.cfg";
#$mailconfig = "/usw/offln/bin/brand-sort.cfg";
$masterconfig = "/usw/src/scripts/prod/all/config/master.cfg";
$tologfile = "/usw/reports/daily/tologs/" . $month . $year . "/tolog" . $day;

###############################################
# Open the Timeout log file and pull the data #
###############################################
open TOLOG, $tologfile or die "Can't open TOLOG.\n";
$junk = <TOLOG>;
$junk = <TOLOG>;
$line = <TOLOG>;
@line = split / +/, $line;
$brand = $line[0];
$data{$brand} = $data{$brand} . $line;

while ($line = <TOLOG>) {
  if ($line =~ /^Total/) {
    $data{$brand} = $data{$brand} . $line . "\n";
    $line = <TOLOG>;
    $line = <TOLOG>;
    @line = split / +/, $line;
    $brand = $line[0];
    if ($brand eq "") {
      $brand="ZZZ";
    }
  }
  $data{$brand} = $data{$brand} . $line;
}
close TOLOG;

##################################################
# Open the mail config file and set up the users #
##################################################
open CONFIG, $mailconfig or die "Can't open $mailconfig\n";
while ($line=<CONFIG>) {
  if ($line !~ /^$|^#/) {
    ($email, $name, $brands) = split /\|/, $line;
    $users{$email}{NAME} = $name;
    $users{$email}{BRANDS} = $brands;
  }
}
close CONFIG;

##################################################################
# Go through each user, and build the data for them, putting the #
# chains in the config file first.                               #
##################################################################
for $user (sort keys %users) {
   $sendfirst = "";
   $sendlast = "";
  $username  = $users{$user}{NAME};
  $brandlist = join " ", split /,/, $users{$user}{BRANDS};
  for $brand (sort keys %data) {
    if ($brandlist =~ /$brand/) { 
      $sendfirst = $sendfirst . $data{$brand};
    } else {
      $sendlast = $sendlast  . $data{$brand};
    }
  }
  open TMPFILE, "> /tmp/mailtmp" or die "Can't open /tmp/mailtmp";
    print TMPFILE $sendfirst . $sendlast;
  close TMPFILE;
  $subject = "Context timeout report for " . $username;
  `/bin/mailx -s \"$subject\" $user < /tmp/mailtmp`;
  `/bin/rm -f /tmp/mailtmp`;
}
