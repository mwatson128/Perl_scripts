#!/usr/bin/perl

($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime();
$date = sprintf("%02d/%02d/%04d %02d:%02d:%02d GMT", $mon + 1, $mday,
                 $year + 1900, $hour, $min, $sec);
print "$date\n";
