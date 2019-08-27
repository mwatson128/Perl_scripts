#!/usr/local/bin/perl
##
## Collate / sort the uswprod* uklogs and email a csv file
##
#use strict;
use Time::Local;

my $DBUG = 0;

my $mon;
my $mday;
my $year;

## Use comand line date if provided
if ($ARGV[0] && $ARGV[0] =~ /^(\d\d)\/(\d\d)\/(\d\d)$/) {
  $mon = $1;
  $mday = $2;
  $year = $3;
} else {
## Today's date
  my ($sec,$min,$hour,$gday,$gmon,$gyear,$wday,$yday,$isdst) = gmtime(time);
  $year = sprintf "%02d",$gyear-100;
  $mon = sprintf "%02d",$gmon+1;
  $mday = sprintf "%02d",$gday;
}

my $workdir = "/`uname -n`/loghist/uklog_all/";
$DBUG && print "Workdir: $workdir\n";
qx(cd $workdir);
my $filename = "uklog${mday}";
my $all_filename = "uklog_${mon}${mday}${year}";
$DBUG && print "Filename: $filename All Filename: $all_filename\n";

my @tpelist = qw (uswprod01 uswprod02 uswprod03 uswprod04);
my @celist = qw (uswprodce01 uswprodce02 uswprodce03 uswprodce04
                 uswprodce05 uswprodce06 uswprodce07 uswprodce08
                 uswprodce09 uswprodce10 uswprodce11 
                 uswprodce13 uswprodce14 uswprodce15);

## Get UKlog files
for my $mach (@tpelist) {
  my $srcdir = "/$mach/logs/uklogs/";

  my $command = "scp usw\@${mach}:$srcdir${filename} ${mach} 2>/dev/null";
  $DBUG && print "$command\n";
  qx($command);
}
for my $mach (@celist) {
  my $srcdir = "/pegs/logs/$mach/uklogs/";

  my $command = "scp usw\@${mach}:$srcdir${filename} ${mach} 2>/dev/null";
  $DBUG && print "$command\n";
  qx($command);
}

## Collate UKlog files
## Just looking for double digit message queuing and Pool messages
my $command = "egrep ' messages in|Pool . is' uswprod0? uswprodce?? | egrep -v ' . mess' | sort -k 2 | sed 's/:/,/' | sed 's/ /,/' | sed 's/ /,/' >  $all_filename";
$DBUG && print "$command\n";
qx($command);

## Clean up Uklogs 
for my $mach (@tpelist) {
  $machlist .= "$mach ";
}
for my $mach (@celist) {
  $machlist .= "$mach ";
}
$DBUG && print "rm $machlist\n";
qx(rm $machlist);

my $command = "uuencode $all_filename $all_filename.csv | mailx -s \"$mon/$mday UK Summary Logs\" pedpg\@pegs.com";
$DBUG && print "$command\n";
qx($command);

my $dir = $mon.$year;
if (! -d $dir) {
  qx(mkdir $dir);
  qx(chmod 775 $dir);
}

# Archive the file
$DBUG && print "mv $all_filename $dir\n";
qx(mv $all_filename $dir);
