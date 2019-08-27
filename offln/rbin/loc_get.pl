#!/bin/perl

$ARGC = @ARGV;
if ($ARGC) {
  $IFP = "<./$ARGV[0]";
  open IFP or die "Can't open input!";
}
else {
  print "Usage: lg_join \<file\> \n";
  print "  output is to stdout.\n";
  exit;
}

$buf = NULL; 

#printf "%s|%s|%s|%s|%s|%s|%s|%s|%s\n",
        #"MSN", "GDS", "HRS", "In Date", "PNR_ID", "First NAM", "Last Name",
	#"IATA", "PID";

while (<IFP>) {
  chomp;
 
  next if (/^\*/);

  if (/^\d\d\/\d\d\/\d\d/) {

    # End of the message.  Process and print.
    @b_segments = split /\|\|+/, $buf;
    foreach $b_segment (@b_segments) {
      ($b_header, @b_fields) = split /\|/, $b_segment;
      foreach $b_field (@b_fields) {
	# The first 3 chars are field id's. Use substr to split.
	$b_amf_tag = substr $b_field, 0, 3;
	$b_amf_str = substr $b_field, 3;
	$b_amf{$b_amf_tag} = $b_amf_str;
      }
    }
    
    # now print the fields we need.
    if ($b_amf{LOC}) {
      # print out an sql statement that will load this info.
      printf "UPDATE booking SET pnr = '%s' ", $b_amf{LOC};
      printf "WHERE usw_msg_num = '%s' ", $b_amf{MSN};
      printf "AND usw_msg_type = '%s' ", $b_amf{TYP};
      printf "AND txn_date = '%s' ", $b_amf{TIM};
      printf "AND pnr IS NULL;\n";
    }

    reset 'b';
    $buf = NULL; 

    $_ =~ /^(\d\d)\/(\d\d)\/(\d\d) (..):(..):(..)/;
    $b_time = "20${3}" . "-" . $1 . "-" . $2 . " " . $4 . ":" . $5 . ":" . $6;
    $b_amf{TIM} = $b_time;
    $_ =~ /Type (.) msg/;
    $b_amf{TYP} = $1;
  }
  else {
    # We need to get rid of the \ at the end.
    if (/\\$/) {
      chomp;
      chop;
      $buf .= $_;
    }
    else {
      chomp;
      $buf .= $_;
    }
  }
}

# There is a full $buf with the last message in it.
# Process
if ($buf) {
  @b_segments = split /\|\|+/, $buf;
  foreach $b_segment (@b_segments) {
    ($b_header, @b_fields) = split /\|/, $b_segment;
    foreach $b_field (@b_fields) {
      # The first 3 chars are field id's. Use substr to split.
      $b_amf_tag = substr $b_field, 0, 3;
      $b_amf_str = substr $b_field, 3;
      $b_amf{$b_amf_tag} = $b_amf_str;
    }
  }
  ($b_nam_last, $b_nam_frst, @b_rest) = split /\//, $b_amf{NAM};
  
  # now print the fields we need.
  if ($b_amf{LOC} && $b_amf{CNF} && $b_amf{IND}) {
    if (($b_amf{ACT} eq "SS") && ($b_amf{BST} eq "ET")) {
      printf "%s|%s|%s|%s|",
	     $b_amf{MSN}, $b_amf{ARS}, $b_amf{HRS}, $b_amf{IND};
      printf "%s|%s|%s|%s|%s\n", 
	$b_amf{LOC}, $b_nam_frst, $b_nam_last, $b_amf{BKS}, $b_amf{PID};
    }
  }
  reset 'b';
}
    
close IFP;
