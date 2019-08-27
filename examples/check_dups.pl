#!/bin/perl
#
#  (]$[) %M%:%I% | CDATE=%G% %U% 

$master_filename="</loghist/master/master.cfg";
$ofp = ">/usw/reports/monthly/chains.cfg";

# GDS's to tack on the end.  Just use all to be sure.
$gdsline = "GDS 1A 1P AA CMR ITS TPI UA|1V|1C|1G WB|MS HD";

# Pegasus Asp customers.  Have to keep a list because of ANMUX breakout.
$pegsasp = "PEG WB WW SG NK TP OG RS QC DR DA LW HF PW VY JP GT PI DD";
$notgood = "ZZ ZZ2 us";
$PR_hrs = "DT ES HG HX";

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

for $hrs (sort keys %hrs_equi) {

  # Skip the "special" cases
  next if ($pegsasp =~ m/$hrs/);
  next if ($notgood =~ m/$hrs/);
  next if ($hrs eq "PR");
  next if ($hrs eq "LQR");
  next if ($hrs eq "PRR");
  next if ($hrs eq "RF2");

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


open OFP, $ofp or die "can't open output file!\n";
# Print the cfg out...
#
print OFP $print_header;
foreach $tmp ( sort keys %chn_bill) {
  print OFP $tmp, "\n";
}

close OFP;
