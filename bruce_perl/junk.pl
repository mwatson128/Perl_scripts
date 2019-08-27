#!/bin/perl
push(@{$MONTH{0,2}},"JANUARY",1);
push(@{$MONTH{0,9}},"FEBRUARY",2);
push(@{$MONTH{0,16}},"MARCH",3);
push(@{$MONTH{7,2}},"APRIL",4);
push(@{$MONTH{7,9}},"MAY",5);
push(@{$MONTH{7,16}},"JUNE",6);
push(@{$MONTH{14,2}},"JULY",7);
push(@{$MONTH{14,9}},"AUGUST",8);
push(@{$MONTH{14,16}},"SEPTEMBER",9);
push(@{$MONTH{21,2}},"OCTOBER",10);
push(@{$MONTH{21,9}},"NOVEMBER",11);
push(@{$MONTH{21,16}},"DECEMBER",12);

foreach $k (sort {$MONTH{$a}->[1] <=> $MONTH{$b}->[1]} (keys %MONTH)) {
print "$k\n";
}
($day,$month,$year) = (localtime)[3,4,5];
$month++;
$year+=1900;

$txtln = sprintf("cp keystore.jks keystore.jks_%d%02d%02d",$year,$month,$day);
print ">$txtln\n";


push(@cluster,'-1/d1c1_');
push(@cluster,'-1/d1c2_');
push(@cluster,'-2/d2c3_');
push(@cluster,'-2/d2c4_');
$server="uswprodce13";
$server =~ m/uswprodce(.*)/;
$servernum = $1;
foreach $cl (@cluster) {
  print "/pegs/nodeagents/$server\_node_agent$cl$servernum/config\n";
}
