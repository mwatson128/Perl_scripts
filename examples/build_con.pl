#!/bin/perl -w
#
# (]$[) build_con.pl:1.2 | CDATE=06/01/09 14:46:40

use Getopt::Std;
$zone = `uname -n`;
chomp $zone;
$date = `date +m+y`;

$master_filename="</$zone/loghist/uswprod01/master/master.cfg";
$cfg_filename="</$zone/usw/reports/monthly/connections/conn_list.cfg";

# GDS's to tack on the end.  Just use all to be sure.
$gdsline = ",@,@,@,@,@,@,@,@,@,@";
$pr_line = ",@,@,@,@,@,@,@,,,";

# Pegasus Asp customers.  Have to keep a list because of ANMUX breakout.
$pegsasp = "PEG NK TP OG RS QC DR DA HF PW VY JP GT PI DD";
@notgood = ("ZZ", "ZZ2", "us", "RV0", "RV2", "RV3", "RV4", "RV5", 
            "RV6", "RV7", "RV8", "RV9", "LRQ", "PRR", "LS");
@no_ads = ("DI", "BU", "HJ", "KG", "MQ", "RA", "RD", "SE", "TL", "TR",
           "WG", "RT", "RF", "NX", "UU", "ZS", "IL", "SI", "WG", "HI",
	   "UV", "HH", "PR", "BH", "MT", "HY", "IL3", "CH");

$PR_hrs = "DT ES HG HX";
$TA_hrs = "TA TV";
$RB_hrs = "RB";

# usage function
sub usage() {
  print "Usage: $0 -m mmyy\n";
  print "      -m mmyy, month year of connections to print\n";
  print "      output: /$zone/usw/reports/monthly/connections/chains_con{mmyy}.csv,\n";
  print "              comma delimited excel import file\n";
} # end of function

getopt('m:');

$ARGC = @ARGV;

# Process month from the command line argument
if ($opt_m) {

  if ( 2 <= $ARGC) {
    print "More than one argument found, using first\n";
  }
  if ($opt_m =~ /\d\d\d\d/) {
    chomp $opt_m;
    $date = $opt_m;
  } else {
    print "Invalid nondecimal argument: $opt_m\n";
    usage();
    exit;
  }
} else {
  usage();
  exit;
}

$ofp = ">/$zone/usw/reports/monthly/connections/chains_con${date}.csv";

$print_header = "HRS Name, HRS Code, 1A, 1P, AA, CMR, ITS, TPI, UA, WB, MS, HD\n";

#
#  Read in master config file
#
open MASTER, $master_filename or die "Can't open MASTER.\n";
$hold = "";
while (<MASTER>) {
  next if /^$|^#/;
  if (/\\$/) {
    chomp;
    chop;
    $hold = $hold . $_;
  }
  else {
    chomp;
    $hold = $hold . $_;
    if ($hold =~ /{/) {
      chomp $hold;
      chop $hold;
      chop $hold;
      $config_type =  $hold;
      $hold = "";
      %hotel = ();
    } elsif ($hold =~ / = /) {
      ($key, $value) = split / = /, $hold;
      $hotel{$key} = $value;
    } elsif ($hold =~ /}/) {
      if ($config_type eq "HRS_EQUIVALENCE") {
        $hrs_equi{$hotel{PRIMARY_ID}} = $hotel{HRS};
      }
      elsif ($config_type eq "A_CONNECTION") {
        @gds_id = split //, $hotel{GDS};
	$gds_prime = $gds_id[0] . $gds_id[1];
        $gds_conn{$gds_prime} .= $hotel{HRS};
      }
      elsif ($config_type eq "B_CONNECTION") {
        if ($hotel{GDS} =~ /URS/) { 
          $gds_conn{URS} .= $hotel{HRS};
        }
	else {
          @gds_id = split //, $hotel{GDS};
          $gds_prime = $gds_id[0] . $gds_id[1];
          $gds_conn{$gds_prime} .= $hotel{HRS};
        }
      }
    }
    $hold = "";
  }
}
close MASTER;

#
#  Read in the chain name config file
#
open CHAIN, $cfg_filename or die "Can't open CHAIN.\n";

$hold = "";
while (<CHAIN>) {
  chomp;
  next if /^$|^#/;
  @chn_fld = split /=/;
  $chn_info{$chn_fld[0]} = $chn_fld[1];
}
close CHAIN;

foreach $hrs (sort keys %hrs_equi) {

  $skip = 0;
  foreach $ng (@notgood) {
    if ($ng eq $hrs) {
      $skip = 1;
    }
  } 

  # Skip the "special" cases
  next if ($pegsasp =~ m/$hrs/);
  next if ($skip);
  next if ($hrs eq "PR");
  next if ($hrs eq "TA");

  $hrs_hold = $hrs;

  $ads = 1;
  foreach $na (@no_ads) {
    if ($hrs eq $na) {
      $ads = 0;
    }
  } 

  @tmp = split / /, $hrs_equi{$hrs};
  foreach $chn (@tmp) {
    
    if ($chn ne $hrs) {
      $hrs_hold .= "|";
      $hrs_hold .= $chn;
    }
  }

  @gds_pres = 0;

  # Build the GDS list based on A_CONN and B_CONN for URS
  foreach $gds_list (sort keys %gds_conn) {

    if (($gds_list =~ /1A/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $gds_pres[0] = 1;
    }
    if (($gds_list =~ /1P/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $gds_pres[1] = 1;
    }
    if (($gds_list =~ /AA/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $gds_pres[2] = 1;
    }
    if (($gds_list =~ /URS/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $gds_pres[3] = 1;
    }
    if (($gds_list =~ /URS/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $gds_pres[4] = 1;
    }
    if (($gds_list =~ /URS/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $gds_pres[5] = 1;
    }
    if (($gds_list =~ /UA/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $gds_pres[6] = 1;
    }
    if ($ads) {
      if (($gds_list =~ /WB/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
	$gds_pres[7] = 1;
      }
      if (($gds_list =~ /MS/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
	$gds_pres[8] = 1;
      }
      if (($gds_list =~ /HD/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
	$gds_pres[9] = 1;
      }
    }
  }

  for($i = 0; $i < 10; $i++) {
    $hrs_hold .= ",";
    if ($gds_pres[$i]) {
      $hrs_hold .= "@";
    }
    else {
      $hrs_hold .= " ";
    }
  }

  # Old way with all GDS's.
  #$hrs_hold .= " " . $gdsline;
  $chn_bill{$hrs} = $hrs_hold;

}

$pegsasp .= " " . $gdsline;
$chn_bill{"PEG"} = $pegsasp;
$PR_hrs .= " " . $gdsline;
$chn_bill{"PR"} = $PR_hrs;
$TA_hrs .= " " . $pr_line;
$chn_bill{"TA"} = $TA_hrs;
$RB_hrs .= " " . $gdsline;
$chn_bill{"RB"} = $RB_hrs;

open OFP, $ofp or die "can't open output file!\n";
# Print the cfg out...
#
print OFP $print_header;
foreach $tmp ( sort keys %chn_bill) {
  if ($chn_info{$tmp}) {
    print OFP "$chn_info{$tmp}, $chn_bill{$tmp}\n";
  }
  else {
    print OFP "NA, $chn_bill{$tmp}\n";
  }
}

close OFP;
