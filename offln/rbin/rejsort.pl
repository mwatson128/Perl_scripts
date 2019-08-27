#!/usr/bin/perl
# (]$[) rejsort.pl:1.9 | CDATE=12/01/00 08:09:20
# /usw/src/offln/scripts/qa

# Quit if $ARGV[0] is empty
die("Please specify \"daily\" or \"weekly\".\n") unless $ARGV[0];

#Set Dates
$DATE = `/usw/offln/bin/getydate`;
$MDATE = `/usw/offln/bin/getydate -s`;

# Get filename of dumper report
if ($ARGV[0] eq "daily") {
  $DUMP = join("", "/usw/reports/",$ARGV[0],"/dumper/",$DATE,".dump");
  $type = "Daily";
}
else {
  $DUMP = join("", "/usw/reports/",$ARGV[0],"/dumper/",$DATE,".wk");
  $type = "Weekly";
}

# Open dump file
open(DUMP, $DUMP) or die "Can't open unsorted reject file\n";

# Skip 3 lines
$head1 = <DUMP>;
$head2 = <DUMP>;
<DUMP>;

# Put the dump into a big array (called "big" appropriately enough)
while(<DUMP>) {
  @line = split;
  $line[3] = <DUMP>;
  chomp $line[3];

  # Push entity, frequency, type (warning or error), and error 
  # text onto array
  push @big, join(":", $line[2],$line[0],$line[1],$line[3]);
}

# Close the dump file
close(DUMP);

sub sorter {
  @a = split(/:/, $a);
  @b = split(/:/, $b);
  if($a[0] eq $b[0]) {
    return $b[1] <=> $a[1];
  }

  # Put IPs (designated by having a "-" in the entity name) first.
  if(index($a[0], "-") > -1 && index($b[0], "-") == -1) {
    return -1;
  } 
  if(index($a[0], "-") == -1 && index($b[0], "-") > -1) {
    return 1;
  } 
  $a[0] cmp $b[0];
}

# Open Configuration File
open DATAFILE, "/usw/offln/bin/rejsort.cfg" or die "No config file found\n";

while (<DATAFILE>) {
  chomp $_;
  # initialize MAILLIST for new username.
  if ( $_ =~ /^#/ || $_ =~ /^$/ ) {
    # Please skip the comments and blank lines.
    next;
  }
  else {
    @info  = split /\|/,$_;
    $userid = $info[1];
    @users = split /,/,$userid;
    $numusers = @users;
    if ($numusers > 1) {
      $MAILLIST = "";
      foreach $user (@users) {
	$MAILLIST .= "$user\@pegs.com";
	$MAILLIST .= " ";
      }
    }
    else {
      $MAILLIST = "$userid\@pegs.com";
    }
    $name = $info[2];

    open DATAFILE1, ">/tmp/rej.$ARGV[0]" or \
	die "Can't open ouput file /tmp/rej.$ARGV[0]\n";

    print DATAFILE1 $head1, $head2, "\n";

    # Entities
    @entlist = split (/,/, $info[3]);

    # Array of entities, messages to be ignored (printed at the end)
    @ignores = (
        "    Text line in segment too long - segment BLABLA, field TXT",
        "    Segment removed to shorten message - segment BLABLA",
        "    Segment contains too many lines of text - segment BLABLA",
        "    NO PROPERTY - segment PALSRQ, field PID",
        "    PROPERTY NOT FOUND - segment PALSRQ, field PID",
        "    INVALID DATE FORMAT - segment PALSRQ",
        );


    # Print team entities
    @entsort = sort sorter (@big);
    
LINE1: foreach $item (@entsort) {
      next if !$item;
      @items = split(/:/,$item);
      foreach $entity (@entlist) {
	if ($entity eq $items[0]) {
	  foreach $ignore (@ignores) {
	    @ignore = split(/:/, $ignore);
	    if ($items[3] eq $ignore[0]) {
	      push @ignore_found, $item;
	      $item = "";
              next LINE1; 
	    }
	  }
	  print DATAFILE1 "$items[1] $items[2] $items[0] \n";
	  print DATAFILE1 $items[3], "\n";
	  $item = "";
	  next; 
	}
      }
    }
    
    # Add TRP's
    foreach $item (@entsort) {
      next unless $item;
      @line = split(/:/,$item);
      if (index($line[0], "TRP") > -1) {
	print DATAFILE1 "$line[1] $line[2] $line[0] \n";
	print DATAFILE1 $line[3], "\n";
        # Remove this element.
	$item = "";
      }
    }

    # Print non-team entities
    print DATAFILE1 "\n\tAnalysis of non-team entities\n";
    print DATAFILE1 "-" x 60, "\n\n";

LINE2: foreach $item (@entsort) {
      @line = split(/:/,$item);
      
      if ($item ne "") {
	foreach $ignore (@ignores) {
	  @ignore = split(/:/, $ignore);
	  if ($line[3] eq $ignore[0]) {
	    push @ignore_found, $item;
	    $item = "";
	    next LINE2;
	  }
	}
	print DATAFILE1 "$line[1] $line[2] $line[0] \n";
	print DATAFILE1 $line[3], "\n";
        # Remove this element.
	$item = "";
      }
    } # end foreach


    # Print the "ignores"
    print DATAFILE1 "\n\tAnalyzed / Hotel Advised\n";
    print DATAFILE1 "-" x 60, "\n\n";

    @ignore_sort = sort sorter (@ignore_found);
    foreach $item (@ignore_sort) {
      @line = split(/:/,$item);
      print DATAFILE1 "$line[1] $line[2] $line[0] \n";
      print DATAFILE1 $line[3], "\n";
    }

    close DATAFILE1;

    `cat /tmp/rej.$ARGV[0] | /usr/ucb/mail -s "$name\'s $type Reject Log Analysis $MDATE\" $MAILLIST`;
#    `rcp /tmp/rej.$ARGV[0] web\@sundev:reject_log_analysis/$ARGV[0]\.$DATE`;
    `rm -f /tmp/rej.$ARGV[0]`;
  }
 
}

close DATAFILE;

