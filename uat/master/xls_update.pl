#!/bin/perl
# commit an entire directory.
#

# get vcs dirs and variables
# Use the ENV{CVSDIR} to get sandbox path
$cvs_dir = $ENV{CVSDIR};
$cur_dir = $ENV{PWD};
if (!$cvs_dir) {
  print "Must have environment variable CVSDIR in profile\n";
  exit;
}

$tmpdir = "/tmp";

if ($ARGV[0]) {
  $updateName = $ARGV[0];
  ($name, $ext) = split /\./, $updateName;
}
else {
  print STDERR "\nEnter new spreadsheet name:\n";
  chomp ($updateName = <STDIN>);
  ($name, $ext) = split /\./, $updateName;
}

$cfgFile = "marriott_fees.cfg";
$convlogfile = "marriott_rates.log";

if ("xls" ne $ext) {
  print "Please make sure your file is saved as 'Excel 93-2003 Workbook'.\n";
  print "It will have an xls extension. \n";
  exit();
}

# Interogate the file name for date info for comment.
if ($updateName =~ /(\d+\D+\d+)/) {
  $fileDate = $1;
  $commentxls = "Checking in update file $updateName with date $fileDate.";
  $commentcfg = "Checking in updated marriott_fees.cfg with update $fileDate changes.";
}
else {
  $fileDate = `date +'%d%b%Y'`;
  $commentxls = "Checking in update file $updateName with date $fileDate.";
  $commentcfg = "Checking in updated marriott_fees.cfg with update $fileDate changes.";
}

# Add new xls to cvs as binary.
`cvs add -kb $updateName 2>&1`;
$rvc = `cvs commit -m \"$commentxls\" $updateName 2>&1`;
print "$rvc\n";

# run script to generate new cfg file
`cvs update -A $cfgFile 2>&1`;
$rvc = `marriott_xlreader.pl -p $cfgFile -n $updateName 2>&1`;
print "$rvc\n";

# commit cfg and new binary files.
$rvc = `cvs commit -m \"$commentcfg\" $convlogfile 2>&1`;
print "$rvc\n";
$rvc = `cvs commit -m \"$commentcfg\" $cfgFile 2>&1`;
print "$rvc\n";

# get the tpe list from tpelist.conf now.                                                     
chomp(my @ceList = `/bin/cat celist.conf`);

# Copy per files from the uswprod servers 
for $system (@ceList) {
  qx(cp $cfgFile ../$system/config); 
}

$rvc = `cd ..; cvs commit -R -m \"$commentcfg\" * 2>&1`;
print "$rvc\n";

