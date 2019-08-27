#!/bin/perl
# commit an entire directory.
#

$zone = `uname -n`;
chomp $zone;
if ($zone =~ /asp\.dhisco/) {
  ($ld, $rest) = split /\./, $zone;
  $zone = $ld;
}

# get vcs dirs and variables
# Use the ENV{CVSDIR} to get sandbox path
$cvs_dir = $ENV{CVSDIR};
$cur_dir = $ENV{PWD};
if (!$cvs_dir) {
  print "Must have environment variable CVSDIR in profile\n";
  exit;
}

$tmpdir = /tmp;

STDERR "\nEnter new spreadsheet name:\n";
chomp ($filename = <STDIN>);

$cfgFile = "marriott_fees.cfg";

# Interogate the file name for date info for comment.
$filename =~ /(\d\d\D\D\D\d\d)/;
$fileDate = $1;
$comment = "Checking in file $filename with date $fileDate.";
`cp $filename $tmpdir`;

# Add new xls to cvs as binary.
`cvs add -kb $filename`;
`cvs commit -m \"$comment\" $filename`;
`cvs admin -kb $filename`;
`cp /tmp/$filename $cur_dir`;
`cvs update -A $filename`;

# run script to generate new cfg file
`marriott_xlreader.pl -p $filename`;

# commit cfg and new binary files.
`cvs update -A $cfgFile`;
`cvs add $cfgFile`;
$rvc = `cvs commit -m \"$comment\" $cfgFile`;

print "Checkin versions:\n$rv\n";

