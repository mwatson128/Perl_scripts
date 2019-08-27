#!/bin/perl

$IFP = "<$ARGV[0]";
open IFP or die "Can't open input file\n";


$cnt = 1;
while (<IFP>) {

  $ipr = $_;
  chomp $ipr;

  # If the line is blank, there's nothing else to do.
  next if ($ipr =~ /^$/);

  @lines = split /\|/, $ipr;

  $key1 = $lines[0] . $lines[1] . $lines[3] . $lines[4];
  $key2 = $lines[5] .  $lines[6] .  $lines[7] .  $lines[8] .  $lines[9];
  $single_key = $key1 . $key2;
  $tm_hrs{$single_key} = $ipr;


#  if ($cnt < 20) {
#    print $lines[0], "  -  ", $lines[1], "\n";
#    $cnt++;
#  }

}
close IFP;

foreach $rec_key (sort %tm_hrs) {
  next if ($tm_hrs{$rec_key} =~ /^$/);
  print $tm_hrs{$rec_key}, "\n";
}
