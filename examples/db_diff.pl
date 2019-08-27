#!/bin/perl
#

$zone = `uname -n`;
chomp $zone;

$old_db = "</$zone/usw/reports/monthly/hrs_tbl/unl/hrs_tbl_prev.unl";
$new_db = "</$zone/usw/reports/monthly/hrs_tbl/hrs_new_load.ld";
$old_tmp = ">/tmp/tmp_old";
$new_tmp = ">/tmp/tmp_new";

open OLD, $old_db or die "Can't open OLD.\n";
open OLD_T, $old_tmp or die "Can't open OLD_TMP.\n";
open NEW, $new_db or die "Can't open NEW.\n";
open NEW_T, $new_tmp or die "Can't open NEW_TMP.\n";

while (<OLD>) {

  next if /^$|^#/;

  @ln = split /\|/, $_;

  $imp = join('|', $ln[0], $ln[1], $ln[2], $ln[3], $ln[4], $ln[5]);
  print OLD_T "$imp\n"; 
} 
  
while (<NEW>) {

  next if /^$|^#/;

  @ln = split /\|/, $_;

  $imp = join('|', $ln[0], $ln[1], $ln[2], $ln[3], $ln[4], $ln[5]);
  print NEW_T "$imp\n"; 
} 
 
close OLD;
close NEW;
close OLD_T;
close NEW_T;

@rv = `diff /tmp/tmp_old /tmp/tmp_new`;

print @rv;

