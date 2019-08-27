#!/bin/perl


  my $cwd = ${ENV{VCSDEV}};
  my $filen = "/etc/passwd";
  my $fileo = "${cwd}/comment_file";
  print "First, /etc/passwd\n";
  print show_when_last($filen);
  print "Then, comment_file\n";
  print show_when_last($fileo);
  exit(0);
  
  sub show_when_last
  {
      my $file = shift @_;
      my ($atime, $mtime) = (stat ($file) )[8,9];
      my $whenstring = "File: $file\n";
      $whenstring .= sprintf ("Mod time in UTC seconds: %d\n", $mtime);
      my %filestats = (Accessed => $atime, Modified => $mtime);
      my ( $modsecs, $days, $hours, $mins, $secs );
      while( my ($term, $ftime) = each %filestats )
      {
	  $modsecs     = (time - $ftime);  # mod time in epoch secs.
	  $days        = $modsecs / 86400; # secs/day
	  $modsecs    %= 86400;            # days remainder
	  $hours       = $modsecs / 3600;  # secs/hour
	  $modsecs    %= 3600;             # hours remainder
	  $mins        = $modsecs / 60;    # secs/min
	  $secs        = $modsecs % 60;    # remaining secs
	  $whenstring .= sprintf ("$term: %02d days, %02d hours, %02d minutes, and %02d seconds ago.\n", $days, $hours, $mins, $secs );
      }
      return $whenstring;
  } # end when_last_access

