#!/bin/perl
#
# (]$[) counthrs.pl:1.1 | CDATE=08/18/00:08:21:23
#

while (<>) {
  # discard line and read again
  chomp;
  $_ = <>;
  chomp;

  # "utt=" line
  if (/utt=/) {
    ($rqt) = /rqt=(\w+)/o;
  }

  # "gds=" line
  $_ = <>;
  chomp;

  # "HDRA2" line
  $_ = <>;
  chomp;
  # join multiple lines
  while (/\\$/) {
    # remove '\'
    chop;
    # append next line
    $_ .= <>;
    # remove newline
    chomp;
  }
  if (/HDRA/) {
    ($hrs) = /\|HRS(\w+)\|/o;
  }

  # increment counter
  if ($rqt) {
    unless ($hrs) {
      $hrs = "00";
    }
    $counter{$hrs}{$rqt} ++;
    $total{$rqt} ++;
  }

  # clear the variables
  $rqt = $hrs = "";
}

# print counter
foreach $hrskey (sort keys %counter) {
  $palsrq = 1 * $counter{$hrskey}{PALSRQ};
  $rpinrq = 1 * $counter{$hrskey}{RPINRQ};
  unless ($hrskey) {
    $hrskey = "00";
  }
  print "HRS $hrskey: ";
  print "PALSRQ $palsrq\tRPINRQ $rpinrq\n";
}

$palsrq = 1 * $total{PALSRQ};
$rpinrq = 1 * $total{RPINRQ};
print "TOTAL: ";
print "PALSRQ $palsrq\tRPINRQ $rpinrq\n";

