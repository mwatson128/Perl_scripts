#!/usr/local/bin/perl -s
use POSIX;

 $infilename = "/home/bfausey/pcmgui.log*2013-06-10";
# open(IN, "hunter 61 minutes from_now for 60 minutes $infilename|") or die "Couldn't open file ($infilename) for processing: $!\n";
 open(IN, "cat $infilename|") or die "Couldn't open file ($infilename) for processing: $!\n";
 while (<IN>) {
   $line = "";
   $line = $_;
   if ($line) {
      @seg = $line =~ /(?:\[(.+?)\])/g;
      $sga='';
      $hit=0;
      print "@seg[0]\n";
#      foreach $prop (@seg) {
#        print "--> $prop\n";
#        if ($prop =~ m/function=TI_(.*)/) {
#           $f = $1;
#        }
#        if ($prop =~ m/sga-GET-<null>=(.*)/) {
#           @tsga = split(",",$1);
#           $sga=@tsga[0];
#        }
#        if ($prop =~ m/^avail_cache_cache_hit-<(.*)>=true/) {
#           ($brand,$pid) = split(";",$1);
#           $brandhits{$brand}++;
#           $hit++;
#        }
#      }
#      ($date) = unpack(a16,@seg[0]);
#      if ($hit != 0) {
#         $hits{"$date|$sga|$f"}+=$hit;
#         $hits{"$sga"}+=$hit;
#      }
   }
 }
 close IN;
#foreach $k (sort {$a cmp $b} (keys %brandhits)) {
#   print "$k|$brandhits{$k}|\n";
#} 
#foreach $k (sort {$a cmp $b} (keys %hits)) {
#   print "$k|$hits{$k}|\n";
#}
exit 0;
