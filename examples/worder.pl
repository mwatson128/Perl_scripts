#!/bin/perl

# read in worf file.
open IFP, "<words" or die "can't open file";

while (<IFP>) {
  chomp;
  push @words_array, $_;
}

close IFP;

my $limit = @words_array;

#print "I read in $limit number of words. \n";
#print "number is $secret \n";

for $i (1..50000) {
#  print "I is  $i\n";
  my $secret = int(1 + rand $limit);
#  print "sectret is $secret, word is $words_array[$secret]\n";
  print "$words_array[$secret] ";
}
