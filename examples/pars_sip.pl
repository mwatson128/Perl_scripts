#!/usr/local/bin/perl

$master_filename="sip2.wb7_a";

open MASTER, $master_filename or die "Can't open $master_filename.\n";
$r_array_cnt = 0;
$g_array_cnt = 0;
$h_array_cnt = 0;
$p_array_cnt = 0;

while ($line = <MASTER>) {
  if ($line !~ /^$|^#/) {
    $hold = "";
    while ($line =~ /\\$/) {
      chomp $line;
      chop $line;
      $hold = $hold . $line;
      $line=<MASTER>;
    }
    $line = $hold . $line;
    chomp $line;
    if ($line =~ /krun/) {
      @break = split /-/, $line;
      foreach $tmp (@break) {
        @l = split / +/, $tmp;
	if ($l[0] eq "r") {
	  push @r_array, $l[1];
	}
	elsif ($l[0] eq "g") {
	  push @g_array, $l[1];
	}
	elsif ($l[0] eq "h") {
	  push @h_array, $l[1];
	}
	elsif ($l[0] eq "p") {
	  push @p_array, $l[1];
	}
      }
    } elsif ($line =~ /ncdctl/) {
      
      @break = split /-/, $line;
      foreach $tmp (@break) {
        @l = split / +/, $tmp;
	if ($l[0] eq "r" and $l[1] ) {
	  push @r_array, $l[1];
	}
	elsif ($l[0] eq "g") {
	  push @g_array, $l[1];
	}
	elsif ($l[0] eq "h") {
	  push @h_array, $l[1];
	}
	elsif ($l[0] eq "p") {
	  push @p_array, $l[1];
	}
      }
    }
  }
}
close MASTER;

printf "-r option,-h option,-g option,-p option\n";
for ($i = 0; $i < 100; $i++) {

  printf "%s,", $r_array[$i] ? $r_array[$i] : " ";
  printf "%s,", $h_array[$i] ? $h_array[$i] : " ";
  printf "%s,", $g_array[$i] ? $g_array[$i] : " ";
  printf "%s", $p_array[$i]  ? $p_array[$i] : " ";
  print "\n";
}

