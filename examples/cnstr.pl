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

$buf = ""; 

while (<IFP>) {
  chomp;
 
  if (/^\*/) {
    next;
  }

# Put in your search separator here:
#  if (/^\d\d\/\d\d/) {
  if (/^store/) {
    
    print $buf, "\n" if ($buf);
    $buf = ""; 
    chop;
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
