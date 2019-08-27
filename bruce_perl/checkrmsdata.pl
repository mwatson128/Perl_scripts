#!/opt/dba/perl5.8.4/bin/perl


$dir2use = (@ARGV[0] ne '') ? @ARGV[0] : $ENV{PWD};


while (<DATA>) {
  chomp;
  $ln = sprintf("%ld",$_);
  $loans{$ln}++;
}



if (-e "$dir2use/$ENV{PREFIX}_sms_from_rms_update_txns.Z") {
  $inpt_cmd = "gzcat $dir2use/$ENV{PREFIX}_sms_from_rms_update_txns.Z |";
} else {
  $inpt_cmd = "<$dir2use/$ENV{PREFIX}_sms_from_rms_update_txns";
}

open(READTEST,$inpt_cmd) || die "could not read $inpt_cmd $! \n";
$chrstr = chr(206);
$rec_ctr = 0;
while(<READTEST>) {
  $line=$_;
  $rec_ctr++;
  print length($line)." bytes read, record number $rec_ctr, ";
  (@breakout) = split($chrstr,$line);
  $ln = sprintf("%ld",@breakout[0]);
  print "found " if (exists $loans{$ln});
  print "loan number @breakout[0] @breakout[1] @breakout[25]\n"; 
  $status{@breakout[0]}+=1;
}
close(READTEST);

foreach $k (keys %status) {
  print "$k $status{$k}\n" if ($status{$k} > 1);
}
exit;
