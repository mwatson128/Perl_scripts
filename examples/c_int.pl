#!/usr/bin/perl

# Script used to copy a "template" Hotel IP for a new customer.

use Getopt::Std;

#########################
# General variable setup
#########################


#########################
# Open Log and print
#########################



# Build the directory structure.


@files = `ls -1d *.c`;
search_files(@files);


sub search_files {

  foreach $ifile (@_) {
    chomp $ifile;

    if ( -T $ifile) {
      open IFP, "<$ifile";
      @ifp_file = <IFP>;
      close IFP;

      $ofile = $ifile . "_new";

      foreach  $ln (@ifp_file) {
	$ln =~ s/uint8/int/g;
	$ln =~ s/int8/int/g;
	$ln =~ s/uint16/int/g;
	$ln =~ s/int16/int/g;
	$ln =~ s/int32/int/g;
	$ln =~ s/uint/uint32/g;
      }
      
      open OFP, ">$ofile";
      foreach $ln (@ifp_file) {
        print OFP $ln;
      }
      close OFP;
    }
    qx(rm -f $ifile);
    qx(cp $ofile $ifile);
    qx(rm -f $ofile);
    
  }
}

