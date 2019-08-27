#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl /home/kdaniel/modules/WEBSERVER/lib);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);

if ($#ARGV < 1 ) {
	print "usage: status|enable|disable dev|qa|uat|bench|prod\n ";
	exit;
}
$mode;
$choice=$ARGV[0];
chomp($choice);
if ( $choice eq "status" ) {
  $mode="CacheStatus=true";
} elsif ( $choice eq "enable") {
  $mode="EnableCache=AllCaches";
} elsif ($choice eq "disable") {
  $mode="DisableCache=AllCaches";
}
$env=$ARGV[1];
chomp($env);

if ($env eq "prod") {
  if ($#ARGV != 2 ) {
    print "usage for production: status|enable|disable prod cluster#\n";
    print "example: cache.pl status prod cluster 1\n";
    exit;
  } 
}
$cluster=$ARGV[2];
chomp($cluster);

if ( $env eq "qa") {
  $file="/home/dhuynh/scripts/qa/qaurl";
} elsif ( $env eq "uat") {
  $file="/home/dhuynh/scripts/uat/uaturl";
} elsif ($env eq "bench") {
#  $file="/home/dhuynh/scripts/bench/benchurl";	
  $file="/home/bfausey/perl/testurl";	
} elsif ($env eq "prod") {
  if ($cluster eq "1" ) {
  $file="/home/dhuynh/scripts/prod/cluster1url";
  } elsif ($cluster eq "2" ) {
   $file="/home/dhuynh/scripts/prod/cluster2url";
  }  elsif ($cluster eq "3" ) {
   $file="/home/dhuynh/scripts/prod/cluster3url";
  } elsif ($cluster eq "4" ) {
   $file="/home/dhuynh/scripts/prod/cluster4url";
  }
}
print "$file\n";
$record = <FILE>;
open (FILE, $file);
while ($record = <FILE>) {
   chomp $record;
   $url ="$record$mode"; 
   print "$url\n";
   &process($url); 
}
close(FILE);

sub process {
  use HTTP::Request::Common;
  use LWP::UserAgent
  $ua = LWP::UserAgent->new;
  my $response = $ua->request(GET $url);
  if ($response->is_success) {
    print $response->decoded_content;  # or whatever
    print "\n";
  }
  else {
     print " -- Server is not responding.\n";
 }
} 
