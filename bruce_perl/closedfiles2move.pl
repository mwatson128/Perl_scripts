#!/usr/bin/perl

$dir = '/docs/e-docs/';
&searchDirectory($dir);
exit(0);

sub searchDirectory {
#set up local variables
    local($dir);
    local(@lines);
    local($line);
    local($file);
    local($archdir);
    local($thisdir);

#initialize valiables
    $dir = $_[0];
    %closed=();

#there should be a file with all the closed files from today
        open(IN, "<docfilesclosed") or die "Couldn't open file for processing: $!";
        while (<IN>) {
          chomp;
          $closed{$_} = 0;
        }
        close IN;

#foreach line from the file move the file 
	foreach $line (sort (keys %closed)) {
            $line =~ s/\|//;
            %thisfile=();
            %thatfile=();
            $found = false;
            $file = $line;
            $thisdir = $dir . $file;
            if (-d $thisdir) {
                @a1 = glob($thisdir . '/*');
                print "$thisdir\n";
                foreach $l1 (@a1) {
                   print "$l1\n";
                }
                $archdir = $dir . 'ARCHIVES-2009/' . $file;
                if (-s $archdir) {
                   print "--> $archdir\n";
                   @a2 = glob($archdir . '/*');
                   foreach $l2 (@a2) {
                      print "--> $l2\n";
                   }
                } 
            }
    	}
}


