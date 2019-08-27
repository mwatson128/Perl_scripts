#!/bin/perl

$IFP = "<$ARGV[0]";
open IFP or die "Can't open input file\n";


$hold = "";
while (<IFP>) {

  $line = $_;
  chomp $line;

  # If the line is blank, there's nothing else to do.
  next if ($line =~ /^$/);

  # If the line end in \ then get rid of the \ and store in hold
  if ($line =~ /\\$/) {
    chop $line;
    $hold .= $line;
  }
  # Normal line ending.
  else {
    $i = 0;
    # If hold has something stored in it, deal with it.
    if ($hold) {
      $hold .= $line;
      print "$hold \n";
      $hold = "";
    }
    # Otherwise, just count off 68 characters and print.
    else {
      print "$line \n";
    }
  } 
}
close IFP;

