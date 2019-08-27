#!/usr/bin/perl
#
#

@f = `ls`;

foreach $file (@f) {

 chomp $file;

 if (-T $file) {
  @t = `tail -7 $file`;

  print "%" x 25, "  ", $file, "  ", "%" x 25, "\n\n";
  print @t, "\n"; 

 }
 else {
  
  print "%" x 25, "  ", $file, "  ", "%" x 25, "\n";
  print "\n    Is not a text file! \n\n";

 }

}
