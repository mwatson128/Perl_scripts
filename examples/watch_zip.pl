#!/bin/perl
#
#
#

@rv = qx(ps -ef | grep uncompress);
@rv2 = qx(ps -ef | grep zip);

foreach $line (@rv) {

  next if ($line =~ /grep|watch_zip/);
  print $line;

}

foreach $line (@rv2) {

  next if ($line =~ /grep|watch_zip/);
  print $line;

}


