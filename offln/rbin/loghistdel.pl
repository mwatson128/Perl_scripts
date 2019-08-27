#!/bin/perl
#Title - loghistdel.pl Perl script to deletes files in the co,
#                      rej, and rpt directories that are 90 days
#                      and per, p2r, qdata and trc directories
#                      that are 31 days old.

# (]$[) loghistdel.pl:1.13 | CDATE=06/19/02 09:05:51

open( LOG, ">>/loghist/history.log") || exit (7);
print LOG "   Started Processing ", `date`,"\n"; 

$co_dir = "/loghist/co/";
$rpt_dir = "/loghist/rpt/";
$rej_dir = "/loghist/rej/";
$per_dir = "/loghist/per/";
$p2r_dir = "/loghist/p2r/";
$qdata_dir = "/loghist/qdata/";
$trc_dir = "/loghist/trc/";


#  Files will be deleted in the following directories
#  that are more than 90 days old.


   print LOG "\nCurrent Directory is $co_dir\n"; 
   chdir $co_dir;
   $list = `find . -mtime +75`;
   print LOG "Removing files:\n", $list;
   qx(find . -mtime +75 -exec rm -f {} "\;"); 

   print LOG "\nCurrent Directory is $rpt_dir\n"; 
   chdir $rpt_dir;
   $list = `find . -mtime +75`;
   print LOG "Removing files:\n", $list;
   qx(find . -mtime +75 -exec rm -f {} "\;");

   print LOG "\nCurrent Directory is $rej_dir\n"; 
   chdir $rej_dir;
   $list = `find . -mtime +75`;
   print LOG "Removing files:\n", $list;
   qx(find . -mtime +75 -exec rm -f {} "\;");

#  Files will be deleted in the following directories
#  that are more than 31 days old.

   print LOG "\nCurrent Directory is $per_dir\n"; 
   chdir $per_dir;
   $list = `find . -mtime +22`;
   print LOG "Removing files:\n", $list;
   qx(find . -mtime +22 -exec rm -f {} "\;");

   print LOG "\nCurrent Directory is $p2r_dir\n"; 
   chdir $p2r_dir;
   $list = `find . -mtime +22`;
   print LOG "Removing files:\n", $list;
   qx(find . -mtime +22 -exec rm -f {} "\;");

   print LOG "\nCurrent Directory is $qdata_dir\n"; 
   chdir $qdata_dir;
   $list = `find . -mtime +22`;
   print LOG "Removing files:\n", $list;
   qx(find . -mtime +22 -exec rm -f {} "\;");

   print LOG "\nCurrent Directory is $trc_dir\n"; 
   chdir $trc_dir;
   $list = `find . -mtime +22`;
   print LOG "Removing files:\n", $list;
   qx(find . -mtime +22 -exec rm -f {} "\;");


print LOG "\n   Processing Ended  ", `date`, "\n"; 


