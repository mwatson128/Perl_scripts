#!/bin/perl
# (]$[) %M%:%I% | CDATE=%G% %U%

# Invoked via MKVOPTS in Makerul.com as follows:
#   -y "`$(USW)/comment.sh $(NOVCS)`"

# Initialize values.
$opened = 1;
$ask_for_comment = 1;
$comment = "Making versionless binary";

if ($ARGV[0] ne "-T") {

  # Get VCSDEV directory
  $cwd = ${ENV{VCSDEV}};

  # Open comment file if there is one.
  $CMTF = "${cwd}/.comment_file";
  open CMTF or ($opened = 0);

  # If there is a file to read from when making a version, see if we should use
  # it.
  if ($opened) {

    # Get file update modify time in UTC.
    my ($mtime) = (stat ($CMTF) )[9];

    # Get current time in UTC.
    $time_now = time();

    # computer difference 
    $laps_sec = $time_now - $mtime;
    #print "MIKEW: laps_sec is $laps_sec \n";
    
    # Check age of the file and don't use if it's more thank 2 hours old
    # and make sure it has a non-zero size (-s).
    if (7200 >= $laps_sec && (-s $CMTF)) {
      $ask_for_comment = 0;
      # use the comment in the file given
      chomp ($comment = <CMTF>);
    }
    else {
      $ask_for_comment = 1;
    }

  } 
  # If no version file to read from then ask about a comment.
  else {
    $ask_for_comment = 1;
  }

  if ($ask_for_comment) {
    print "\nPut comments in $CMTF to automate the compile process.";
    print "\ncomment? ";
    chomp ($comment = <>);
  }

  # print the right comment information, either from a file or entered by hand
  print "$comment\n";

}

