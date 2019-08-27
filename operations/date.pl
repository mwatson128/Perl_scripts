#!/bin/perl

$gmtdate = `date -u`;
chomp $gmtdate;
print "GMT date: $gmtdate\n";
