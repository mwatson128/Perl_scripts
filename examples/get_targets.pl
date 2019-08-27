#!/bin/perl -w

@ls_res = `ls -1 *.c *.rd *.h *setup saip master.cfg Makefile .make_comment 2> /dev/null`;
$res = "";

foreach $targ (@ls_res) {

  chomp $targ;

  next if ($targ =~ /"no such file"/);
  next if ($targ =~ /V.c/);

  $res .= "$targ ";

}

print $res;

