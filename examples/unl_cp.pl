#!/bin/perl

$ARGC = @ARGV;
if ($ARGC) {
  $IFP = "<./$ARGV[0]";
  open IFP or die "Can't open input!";
}
else {
  print "Usage: lt_fmt.pl file \n";
  print "  output is to stdout.\n";
  exit;
}

# output unbuffered
$| = 1;

while (<IFP>) {
  chomp;
 
  next if (/^\*/);

  #$cnt = tr/\|//d;
  $cnt = tr/	/|/;

  print $_, "\n";

}
      

close IFP;
