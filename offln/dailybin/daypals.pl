#!/bin/perl
# (]$[) %M%:%I% | CDATE=%G% %U%
######################################################################
#  This will generate a list of the pals requests 
######################################################################

#########################
#  Function Definition  #
#########################

sub load_chains_cfg;

#######################
#  Environment Setup  #
#######################
@day_abbr = qw (Sat Sun Mon Tue Wed Thu Fri);
$ENV{PATH} = "/usw/offln/bin:/bin:/usr/bin:/usr/.ucbucb:/usr/local/bin:/usr/ucb:/usw/reports/monthly/bin:/pdl/bin:/home/uswrpt/teTeX/bin/sparc-solaris2.5/";
$ENV{INFORMIXDIR} = "/informix";
$ENV{ONCONFIG} = "onconfig.ped_test";
$ENV{INFORMIXSERVER} = "ped_test_shm";
$rootdir = "/usw/reports/daily/perf/pals";
$workdir = $rootdir . "/data";
$date=`getydate -s`;
$day=`date +%u`;
$day--;

@hrs_list=();

load_chains_cfg;

##############################
#  Pop line from chains_cfg  #
##############################
while ($#chains_cfg > -1) {
  $cfg_line = pop @chains_cfg;
  chomp $cfg_line;
  ($hrs_list, $gds_list) = split / GDS /, $cfg_line;
  @HRS = split / +/, $hrs_list;
  @GDS = split / +/, $gds_list;
  @GDS = ("1A", "1P", "AA", "MS", "UA", "WB");

  ########################
  #  Gather Information  #
  ########################
  foreach $hrs (@HRS) {
    %data = {};
    $rawdata = `cat $workdir/$hrs.pals | fgrep "Number of transactions processed"`;
#    $rawdata = `perfa2 -h \"$hrs\" -t $date -s PALS | fgrep "Number of transactions processed"`;
    ($junk, $value) = split /  +/, $rawdata;
    $data{ALL} = $value;
    foreach $gds (@GDS) {
      $outfile = $workdir . "/" . $hrs . "_" . $gds . "pals";
      $rawdata = `cat $outfile | fgrep "Number of transactions processed"`;
#      $rawdata = `perfa2 -a \"$gds\" -h \"$hrs\" -t $date -s PALS | fgrep "Number of transactions processed"`;
      ($junk, $value) = split /  +/, $rawdata;
      $data{$gds} = $value;
    }
    ########################
    #  Output Information  #
    ########################
    ($hrs_real, $hrs_translated) = split /\|/, $hrs;
    $filename = $workdir . "/" . lc $hrs_real . ".pals";
    open FIL, ">> $filename" or die "Can\'t open $filename to append.\n";
    printf FIL "%s:  %s    %7d  %7d  %7d  %7d  %7d  %7d  %7d\n", $day_abbr[$day], 
         $date, $data{ALL}, $data{"1A"}, $data{"1P"}, $data{AA}, $data{MS},
         $data{UA}, $data{WB}; 
    close FIL;
foreach $hrs (sort @hrs_list) {
  ($real, $translated) = split /\|/, $hrs;
  printf "%s           %8d     %8d\n", $real, $datahash{$hrs}{10}, $datahash{$hrs}{11};
}
}  # END while ($#chains_cfg > -1)
}

#########################
#  Function Definition  #
#########################

sub load_chains_cfg {
  $filename = "/usw/reports/monthly/chains.cfg";
  open FIL, "$filename" or die "Can\'t open $filename to read.\n";
  while ($line = <FIL>) {
    if ($line !~ /^#|^$/) {
      push @chains_cfg, $line;
    } 
  }
  close FIL;
  @chains_cfg = ();
  push @chains_cfg, "HI YZ GDS 1A 1P AA UA|1V|1C|1G WB MS";
}
