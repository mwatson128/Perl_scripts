#!/bin/perl
#
#  (]$[) build_chns.pl:1.4 | CDATE=01/25/08 09:41:47 

$zone = `uname -n`;
chomp $zone;

$master_filename="</$zone/loghist/uswprod01/master/master.cfg";
$ofp = ">/$zone/usw/reports/monthly/chains.cfg";

# GDS's to tack on the end.  Just use all to be sure.
$gdsline = "GDS 1A 1P AA CMR ITS TPI UA|1V|1C|1G WB|MS HD";

# Pegasus Asp customers.  Have to keep a list because of ANMUX breakout.
$pegsasp = "PEG TP OG RS QC DR DA HF PW VY JP GT PI DD";
@notgood = ("ZZ", "ZZ2", "us", "RV0", "RV2", "RV3", "RV4", "RV5", 
            "RV6", "RV7", "RV8", "RV9", "DI2", "BU2", "HJ2", "KG2", 
	    "MQ2", "RA2", "RD2", "SE2", "TL2", "TR2", "WG2", "RT2",
	    "RT3", "RF2", "LRQ", "PRR", "NX2", "UU2", "ZS2", "IL2",
	    "HI2", "PR2", "UV2", "HH2", "BH2", "MT2", "SI2", "LS",
	    "IL4", "HY2", "CH2");
$PR_hrs = "DT ES HG HX";
$TA_hrs = "TA TV";
$RB_hrs = "RB";

$print_header = "######################################################################## \
# configuration file for monthly billing. \
# \
# This file is auto-genereated by build_chns.pl  Do NOT edit. Your \
# your changes will be lost! \
######################################################################## \
";

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

  @tmp = split / /, $hrs_equi{$hrs};
  $hrscnt = @tmp;
  foreach $chn (@tmp) {
    
    if ($chn ne $hrs) {
      $hrs_hold .= " ";
      $hrs_hold .= $chn;
    }
  }

  $hrs_hold .= " GDS";
  $ads_flag = "FALSE";

  # Build the GDS list based on A_CONN and B_CONN for URS
  for $gds_list (sort keys %gds_conn) {

    if (($gds_list =~ /1A/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $hrs_hold .= " 1A";
    }
    elsif (($gds_list =~ /1P/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $hrs_hold .= " 1P";
    }
    elsif (($gds_list =~ /AA/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $hrs_hold .= " AA";
    }
    elsif (($gds_list =~ /URS/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $hrs_hold .= " CMR ITS TPI";
    }
    elsif (($gds_list =~ /UA/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $hrs_hold .= " UA|1V|1C|1G";
    }
    elsif (($gds_list =~ /WB|MS/) && 
          ($gds_conn{$gds_list} =~ m/$hrs/) && 
          ($ads_flag ne "TRUE")) {
      $hrs_hold .= " WB|MS";
      $ads_flag = "TRUE";
    }
    elsif (($gds_list =~ /HD/) && ($gds_conn{$gds_list} =~ m/$hrs/)) {
      $hrs_hold .= " HD";
    }
  }

  # Old way with all GDS's.
  #$hrs_hold .= " " . $gdsline;
  $chn_bill{$hrs_hold} = $hrs_hold;

}

$pegsasp .= " " . $gdsline;
$chn_bill{$pegsasp} = $pegsasp;
$PR_hrs .= " " . $gdsline;
$chn_bill{$PR_hrs} = $PR_hrs;
$TA_hrs .= " " . $gdsline;
$chn_bill{$TA_hrs} = $TA_hrs;
$RB_hrs .= " " . $gdsline;
$chn_bill{$RB_hrs} = $RB_hrs;

open OFP, $ofp or die "can't open output file!\n";
# Print the cfg out...
#
print OFP $print_header;
foreach $tmp ( sort keys %chn_bill) {
  print OFP $tmp, "\n";
}

close OFP;
