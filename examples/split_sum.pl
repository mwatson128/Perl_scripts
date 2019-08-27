#!/bin/perl
#
# write a perl script that:
#   splits per011006.sum file in half
#   and configures the ld_ and ld.cfg files correctly.
#

# Geg date to run...
if ( $ARGV[0] > 1 ) {
  $DATE = $ARGV[0];
}

# Begin by getting the per from /usw/reports/daily/per
#`gzcat /usw/reports/daily/per/per${DATE}.sum > per${DATE}.sum`;

# wc -l on the sum file to find out where to split
@wc_o = `wc -l per${DATE}.sum`;

$linecnt = ($wc_o[0] / 2) + 2;

# make a sum_split script, then split the sum file
open SP, ">sum_split" or die "Can't open/create sum_split!\n";
print SP ":\nsplit -l $linecnt per${DATE}.sum per${DATE}\n";
close SP;

`chmod 775 sum_split`;
`sum_split`;

# create ld_ files
open LDA, ">ld_${DATE}aa" or die "Can't open/create ld_$DATEaa!\n";
print LDA ":\n/informix/bin/dbload -c ld${DATE}aa.cfg -d usw_perf -n 50000  -l dbload.errors -r >> /dev/null\n";
close LDA;

open LDB, ">ld_${DATE}ab" or die "Can't open/create ld_$DATEab!\n";
print LDB ":\n/informix/bin/dbload -c ld${DATE}ab.cfg -d usw_perf -n 50000  -l dbload.errors -r >> /dev/null\n";
close LDA;

# create ld_.cfg files
open CFGA, ">ld${DATE}aa.cfg" or die "Can't open/create ld$DATEaa.cfg!\n";
print CFGA "FILE per${DATE}aa DELIMITER '|' 9;\n";
print CFGA "INSERT INTO a2perf;\n";
close CFGA;

open CFGB, ">ld${DATE}ab.cfg" or die "Can't open/create ld$DATEab.cfg!\n";
print CFGB "FILE per${DATE}ab DELIMITER '|' 9;\n";
print CFGB "INSERT INTO a2perf;\n";
close CFGB;

`chmod 775 ld_${DATE}aa`;
`chmod 775 ld_${DATE}ab`;

#`ld_$DATEaa`;
#`ld_$DATEab`;

