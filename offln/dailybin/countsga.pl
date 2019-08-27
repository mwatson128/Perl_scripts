#!/bin/perl
#
# (]$[) countsga.pl:1.1 | CDATE=08/18/00:08:21:19
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
    ($sga) = /\|SGA(\w+)\|/o;
  }

  # increment counter
  if ($rqt) {
    unless ($sga) {
      $sga = "00";
    }
    $counter{$sga}{$rqt} ++;
    $total{$rqt} ++;
  }

  # clear the variables
  $rqt = $sga = "";
}

# print counter
foreach $sgakey (sort keys %counter) {
  $palsrq = 1 * $counter{$sgakey}{PALSRQ};
  $rpinrq = 1 * $counter{$sgakey}{RPINRQ};
  unless ($sgakey) {
    $sgakey = "00";
  }
  print "SGA $sgakey: ";
  print "PALSRQ $palsrq\tRPINRQ $rpinrq\n";
}

$palsrq = 1 * $total{PALSRQ};
$rpinrq = 1 * $total{RPINRQ};
print "TOTAL: ";
print "PALSRQ $palsrq\tRPINRQ $rpinrq\n";

