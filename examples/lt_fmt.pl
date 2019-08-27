#!/usr/bin/perl

$ARGC = @ARGV;
if ($ARGC) {
  $IFP = "< ./$ARGV[0]";
  open IFP or die "Can't open input!";
}
else {
  print "Usage: lt_fmt.pl filetoconvert \n";
  print "  output is to stdout.\n";
  exit;
}

$count=0;

while (<IFP>) {
 chomp;
 
 # figure out is the info is AMF or line trace
 # if it's AMF then just split into lines, if
 # it's NON-AMF then take the garbage off the front.
 if (/\|/) {
 @a = split /\|/;  
 $pline = $a[1]; 
 @s = split //, $pline;
 foreach $w (@s) {
   print "$w";
   $count++;
   if ($count >= 75) {
     print "\\\n";
     $count = 0;
   }
 } 
 }
 else {
   print "\n";
   $count = 0;
 }
 
}

print "\n";


