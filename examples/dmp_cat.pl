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

#$ln_cnt = 0;
$buf = ""; 

while (<IFP>) {
  chomp;
 
  next if (/^\*/);

  if (/^ +\d+: /) {
     
    print $buf, "MIKEW \n";
    #if (5000 > $ln_cnt) {
      #$ln_cnt++;
    #}
    #else {
      #exit(0);
    #}
    $buf = ""; 
    $buf .= $_;
  }
  else {
    # We need to get rid of the \ at the end.
    if (/\\$/) {
      chomp;
      chop;
      $buf .= "$_";
    }
    else {
      chomp;
      $buf .= "$_";
    }
  }
}
      
print $buf, "\n";

close IFP;
