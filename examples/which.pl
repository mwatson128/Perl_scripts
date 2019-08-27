#!/usr/local/bin/perl
# (]$[) %M%:%I% | CDATE=%G% %U%
# Quick script to find participant's comm engine

if ($ARGV[0]) {
  $pt = $ARGV[0];
}
else {
  print "Search for Participant Comm engines\n";
  print "Give participant brand code or CE\n";
  exit(0);
}

$zone = "uswsd01";
$statsub = "/$ZONE/prodsd/config/statsub.cfg";

# CE check
@ceval = `ssh $zone grep TCPSES $statsub | grep Child`;

if ($ceval[0]) {
  foreach $ln (@ceval) {
    @tmp1 = split /\//, $ln;
    @tmp2 = split /_NCD/, $tmp1[0];
    $ce_list{$tmp2[0]} = $tmp1[1];
    $num_list{$tmp1[1]} = $tmp2[0];
  }
}
else {
  print "CE list could not be populated.\n";
  exit(0);
} 

# If a CE is asked for, use a different grep.
if (4 < length($pt)) {
  # Look through the num_list for CE name 
  $uc_pt = uc $pt;
  $pt2 = $num_list{$uc_pt};
  @ptval = `ssh $zone grep $pt2 $statsub`;
  $pt = $uc_pt;
}
else {
  $uc_pt = uc $pt;
  #brand check
  @ptval = `ssh $zone grep $uc_pt $statsub`;
  $pt = $uc_pt;
}

print "Brand \t-  Comm Engine\n";
print "----------------------\n";
if (!($pt2) && $ptval[0]) { 

  $srch_a = $pt . "A2"; 
  $srch_b = $pt . "B2"; 
  $prn_a = $pt . "-A2";
  $prn_b = $pt . "-B2";

  foreach $ln (@ptval) {
    # Look for Type A
    if ($ln =~ $srch_a) {
      @tmp1 = split /_NCD/, $ln;
      $cea = $ce_list{$tmp1[0]};
    }
    # Look for Type B
    if ($ln =~ $srch_b) {
      @tmp1 = split /_NCD/, $ln;
      $ceb = $ce_list{$tmp1[0]};
    }
  } 
  
  # Once through, print out.
  if (!$cea && !$ceb) {
    print "Argument Not Found, you can look on sd01 config/statsub.cfg\n";
  }
  else {
    print "$prn_a \t- $cea\n" if $cea;
    print "$prn_b \t- $ceb\n" if $ceb;
  }
}
elsif ($pt2 && $ptval[0]) { 

  # Code to figure out which. HRS are on this CE.
  foreach $ln (@ptval) {
    @tmp1 = split /NCD!/, $ln;
    @tmp2 = split /_1/, $tmp1[1];
    $tmp2 = @tmp2;
    if (1 < $tmp2) { 
      $this_ce{$tmp2[0]} = $tmp2[0];
    }
  }
  foreach $ln (sort keys %this_ce) {
    print "$ln \t- $pt\n";
  }
}
else {
  print "Participant not recognized, please try again\n";
  exit(0);
}


