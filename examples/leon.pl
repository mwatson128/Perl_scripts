#!/bin/perl
###########################################################################
# month_end.pl - Script for month end billing for Ultraswitch. 1.8
# (]$[) month_end.pl:1.8 | CDATE=11/29/06 14:44:25
###########################################################################
#
# Perl script to automate the data gathering needed to compile Month end
# Ultraswitch billing.
#
###########################################################################
$zone = `uname -n`;
chomp $zone;
print $zone;
