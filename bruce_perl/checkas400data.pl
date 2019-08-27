#!/bin/perl

use Sybase::DBlib;

$dir2use = (@ARGV[0] ne '') ? @ARGV[0] : $ENV{PWD};

$dbs = new Sybase::DBlib $ENV{SMSID}, $ENV{SMSPWD}, $ENV{OPR_DSQUERY} || 
     die "connection to $ENV{OPR_DSQUERY} failed $!\n";

open(READTEST,"<new_as400_rec.h") || die "could not read as400_rec.h $! \n";
while (<READTEST>) {
  chomp($_);
  $_ =~ m/^#define (.*)     (.*),(.*),(.*),(.*)$/;  
  $f = $1;
  $s = $2;
  $l = $3;
  $t = $5;
  $f =~ s/\s+$//;
  $t =~ s/\s+$//;
  push(@{$rec{$f}},$s,$l,$t) if ($f ne '');
}
close(READTEST);

(@headers) = (sort {$a cmp $b} (keys %rec));

if (-e "$dir2use/$ENV{PREFIX}_sms_from_as400_update_txns.Z") {
  $inpt_cmd = "gzcat $dir2use/$ENV{PREFIX}_sms_from_as400_update_txns.Z |";
} else {
  $inpt_cmd = "<$dir2use/$ENV{PREFIX}_sms_from_as400_update_txns";
}

open(READTEST,$inpt_cmd) || die "could not read $inpt_cmd $! \n";

$rec_ctr = 0;
while(<READTEST>) {
  $line=$_;
  $rec_ctr++;
  print length($line)." bytes read, record number $rec_ctr, ";
  foreach $r (sort {$rec{$a}->[0] <=> $rec{$b}->[0]} (keys %rec)) {
    $start = ($rec{$r}->[0] - 1);
    $len =  $rec{$r}->[1];
    if ($r ne '') {
      $col = unpack("x$start a$len",$line);
      $exp{$r,$rec_ctr}=$col;
    }
  }
  print "loan number $exp{LOAN_NUMBER,$rec_ctr}, $exp{ENOTE_INDICATOR,$rec_ctr}\n";
}

close(READTEST);

$dbs->dbclose;
exit;
