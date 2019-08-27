#!/usr/local/bin/perl

$master_filename="</loghist/master/master.cfg";

open MASTER, $master_filename or die "Can't open MASTER.\n";

while ($line = <MASTER>) {
  if ($line !~ /^$|^#/) {
    $hold = "";
    while ($line =~ /\\$/) {
      chomp $line;
      chop $line;
      $hold = $hold . $line;
      $line=<MASTER>;
    }
    chomp $line;
    $hold .= $line;
    $line = $hold;
    if ($line =~ /{/) {
      chomp $line;
      chop $line;
      chop $line;
      $config_type = $line;
      %hold = ();
    } elsif ($line =~ / = /) {
      ($key, $value) = split / = /, $hold;
      $hold{$key} = $value;
    } else {
      if ($config_type eq "HRS_EQUIVALENCE") {
        $hrs_equi{$hold{PRIMARY_ID}} = $hold{HRS};
      }
    }
  }
}

for $hrs (sort keys %hrs_equi) {
  printf "%s = %s\n", $hrs, $hrs_equi{$hrs};
}

close MASTER;
