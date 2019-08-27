#!/usr/bin/perl
#

$zone = `uname -n`;
chomp $zone;

$ARGC = @ARGV;

if ($ARGC) {
  $chn = uc $ARGV[0];
  print "CHN is $chn\n";
}
else {
  $chn = "";
}

@lines = qx(rt-awk 8);

foreach $ln (@lines) {
  if ($chn) {
    if ($ln =~ /$chn/) {
      if ($ln =~ /is (down|up)/) {
        print $ln;
      }
    }
  }
  else {
    if ($ln =~ /is (down|up)/) {
      print $ln;
    }
  }
}

