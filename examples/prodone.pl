#!/bin/perl
#
# (]$[) prodone.pl:1.4 | CDATE= 09:37:13:12/15/00
#
# UltraSwitch monthly(on the 15th) e-mail of product-one participants
#

## 3196

# get all of the mailing lists & utilities
require "/usw/offln/stdperl";

{
  my($start) = 0;
 
  $file =  "/usw/src/offln/dbutils/dtally/sessionctrl.c";
  open(FILE, $file) || die("cannot open $file ");

  $ofile =  ".prodone";
  open(OFILE, ">$ofile") || die("cannot open $ofile ");
    print (OFILE "\tGalileo Product-One Hotel Codes\n\n");

  while ($_ = <FILE>) {
  
    ## don't start until we see the list variable
    if ($_ =~ /static char \*/) {
      $start = 1;
    }
    unless ($start) {
      next;
    }

    ## once we see a NULL_CP we're at the end of the list, so we can leave
    if ($_ =~ /NULL_CP/) {
      last;
    }

    ## find the comment lines that name the HRS for the chains
    if ($_ =~ /\/\*.*\*\//) {
      print (OFILE "\n", $_);
    }
  
    ## get all lines for Galileo session control
    if ($_ =~ /UA/) {
      print (OFILE $_);
    }
  }
  close(OFILE);

  ## make the mail happen
  $date = `getydate -s`;
  $title = "$date: List of Product-One Hotels for Galileo";

  system ("/usr/local/bin/elm -s \"$title\" ${DL_{DL_PRODONE}} < ${ofile}");

}
