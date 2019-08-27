#!/bin/perl

$ARGC = @ARGV;
if ($ARGC) {
  $IFP = "<./$ARGV[0]";
  open IFP or die "Can't open input!";
}
else {
  print "Usage: org.pl file \n";
  print "  output is to stdout.\n";
  exit;
}

# Org structure is:
# record {
#    date,
#    type,
#    check #,
#    descipt,
#    ammount,
#    date,



$buf = ""; 

while (<IFP>) {
  chomp;
 
  if (/^\*/) {
    next;
  }

  if (/^\d\d\/\d\d/) {
    
    print $buf, "\n" if ($buf);
    $buf = ""; 
    $buf .= $_;
  }
  else {
    # We need to get rid of the \ at the end.
    if (/\\$/) {
      chomp;
      chop;
      $buf .= $_;
    }
    else {
      chomp;
      $buf .= $_;
    }
  }
}
      
print $buf, "\n";

close IFP;
