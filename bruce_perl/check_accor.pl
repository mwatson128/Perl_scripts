#!/usr/bin/perl

        open(IN, "<xm.org") or die "Couldn't open file for processing: $!";
        while (<IN>) {
          chomp;
          $closed{$_} = 0;
        }
        close IN;

        open(IN, "<xm.unl") or die "Couldn't open file for processing: $!";
        while (<IN>) {
          chomp;
          @ln = split('\|',$_);
          $unload{@ln[1]} = join('|',@ln);
        }
        close IN;

#foreach line from the file move the file 
	foreach $line (sort (keys %closed)) {
          open(IN,"grep $line xm.out|") or die "Couldn't grep: $!";
          $xm = <IN>;
          chomp($xm);
          close IN;
          open(IN,"grep $line extract.out|") or die "Couldn't grep: $!";
          $ex = <IN>;
          chomp($ex);
          close IN;
          if (exists $unload{$line}) {
             @ln = split('\|',$unload{$line});
             if ($xm) {
                print  "$line has @ln[2] lang records, and is in prop table|$ex\n"; 
             } else {
                print  "$line has @ln[2] lang records, and not in prop table|$ex\n"; 
             }
          } else {
             if ($xm) {
                print  "$line not in prop_ml but in prop table|$ex\n"; 
             } else {
                print  "$line not in prop_ml and not in prop table|$ex\n"; 
             }
          }
    	}
