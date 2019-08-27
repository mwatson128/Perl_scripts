#!/bin/perl
# (]$[) %M%:%I% | CDATE=%G% %U%

$IFP = $ARGV[0];

open IFP or die "can't find file";

while (<IFP>) {
  chomp;

  # derive the directory names.
  @data = split /\|/;

  # 7 is GRT, 8 is HRT
  if (100 < $data[7]) {
    print (join("|", @data));
  }
}

