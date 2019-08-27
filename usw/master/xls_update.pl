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

STDERR "\nEnter spreadsheet update name:\n";
chomp ($updateName = <STDIN>);

$cfgFile = "marriott_fees.cfg";
$cfgFileminus = "marriott_fees.cfg-";

# Interogate the file name for date info for comment.
$updateName =~ /(\d\d\D\D\D\d\d)/;
$fileDate = $1;
$comment = "Checking in update file $updateName with date $fileDate.";
`cp $updateName $tmpdir`;

# Add new xls to cvs as binary.
`cvs add -kb $updateName`;
`cvs commit -m \"$comment\" $updateName`;
`cvs admin -kb $updateName`;
`cp /tmp/$updateName $cur_dir`;
`cvs update -A $updateName`;

# run script to generate new cfg file
`cvs update -A $cfgFile`;
`cvs update -A $cfgFileminus`;
`marriott_xlreader.pl -p $cfgFile -n $updateName`;

# commit cfg and new binary files.
`cvs commit -m \"$comment\" $cfgFile`;
$rvc = `cvs commit -m \"$comment\" $cfgFile`;

print "Checkin versions:\n$rv\n";

