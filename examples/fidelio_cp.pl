#!/usr/bin/perl

# Script used to copy a "template" Hotel IP for a new customer.
# The fid_gen template is a current copy of West Coast.

use Getopt::Std;

#########################
# General variable setup
#########################
$LOG = ">> /home/mwatson/CRS_cp.log";


#########################
# Open Log and print
#########################
open LOG or print "WARNING: Can't open $LOG";
print LOG "\n\n>>--- Fideleo_cp.pl Starting `/bin/date` --<<\n";

getopts('n:b:');

if (!$opt_n) {
  print "usage: fideleo_cp.pl -n <Name> -b <CHN code>\n";
  exit 0;
}
elsif (!$opt_b) {
  print "usage: fideleo_cp.pl -n <Name> -b <CHN code>\n";
  exit 0;
}

$name = $opt_n;
$lc_name = lc $name;
$brand = $opt_b;
$lc_brand = lc $brand;

print LOG "      Start of conversion for $name, brand code: $brand\n";

# Build the directory structure.
qx(mkdir /usw/src/ip2/$lc_name);
qx(mkdir /usw/src/ip2/$lc_name/a);
qx(mkdir /usw/src/ip2/$lc_name/b);
qx(cp -rf /usw/src/ip2/fid_gen/a/* /usw/src/ip2/$lc_name/a/);
qx(cp -rf /usw/src/ip2/fid_gen/b/* /usw/src/ip2/$lc_name/b/);

print LOG "      Directory structure made....\n";

print LOG "      Calling search_files on $lc_name A....\n";

@files = `ls -1d /usw/src/ip2/$lc_name/a/*`;
search_files(@files);

print LOG "\n      Calling search_files on $lc_name B....\n";
@files = `ls -1d /usw/src/ip2/$lc_name/b/*`;
search_files(@files);

print LOG "\n\n      I'm through and Out!\n";
close LOG;
exit(0);


sub search_files {

  print LOG "          I'm in search_files...\n";

  foreach $ifile (@_) {
    chomp $ifile;
    print LOG "      Searching file: $ifile...\n";

    if ( -T $ifile) {
      print LOG "      $ifile is a Text file....\n";
      open IFP, "<$ifile";
      @ifp_file = <IFP>;
      close IFP;

      $ofile = $ifile;
      $ofile =~ s/zzzzz/$lc_name/;
      $ofile =~ s/xx/$lc_brand/;


      foreach  $ln (@ifp_file) {
	$ln =~ s/XXXXX/$name/g;
	$ln =~ s/zzzzz/$lc_name/g;
	$ln =~ s/ZZ/$brand/g;
	$ln =~ s/xx/$lc_brand/g;
      }
      
      print LOG "output file: $ofile\n";
      open OFP, ">$ofile";
      foreach $ln (@ifp_file) {
        print OFP $ln;
      }
      close OFP;
    }
  }
}


