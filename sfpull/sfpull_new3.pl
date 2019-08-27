#!/usr/bin/perl
#
# sfpull.pl - This script will pull messages off a CHN's type B queue,
# store it on the filesystem and email it to someone you name in the
# -e argument. The default email is pedpg@pegs.com
#
#  Usage: sfpull -c <CHN> -e <email@address.com> 
#    -c <CHN> -e <email@address.com> 
#    -e <email@address.com> default is pedpg@pegs.com
#    -v verbose, don't purge just copy and print 
# 
# (]$[) %M%:%I% | CDATE=%G% %U%

use Getopt::Std;
use Time::Local;
use integer;

$zone = `uname -n`;
chomp $zone;

# Using the LOGNAME env variable determine which TPE we are on.
if ($ENV{LOGNAME} =~ /^usw$|^prod_sup$/) {
  $fldirs = "/$zone/prod/QPURGE";
  $ENVF = "/$zone/prod/home/.sf_env";
  #$ENV{'TZ'} = 'UTC';
}
elsif ($ENV{LOGNAME} eq "qa") {
  $fldirs = "/uswqa01/qa/QPURGE";
  $ENV{'TZ'} = 'GMT0';
  $ENVF = "/home/uat/.sf_env";
}
else {
  $fldirs = "/home/mwatson/QPURGE";
  $ENV{'TZ'} = 'GMT0';
  $ENVF = "/home/mwatson/environment";
}

print "Argv is now $ARGV[0] \n";
print "We've gotten to the real program \n";
print "prod dir is $ENV{PRODDIR} \n";

