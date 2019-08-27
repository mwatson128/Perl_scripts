#!/bin/perl
# commit an entire directory.
#
# (]$[) cvs_inst_dir.pl:1.1 | CDATE=11/19/09 15:58:10

# Only commit binaries on pegsdev17 for now.
$zone = `uname -n`;
chomp $zone;

#if ("pegsdev17" eq $zone) {

  # get vcs dirs and variables
  # Use the ENV{CVSDIR} to get sandbox path
  $cvs_dir = $ENV{CVSDIR};
  if (!$cvs_dir) {
    print "Must have environment variable CVSDIR in profile\n";
    exit;
  }
  $bin_dir = $cvs_dir . "/usw/ce/uswbin";

  # Read in cvs comment file into $cvs_comm variable.
  $cvs_comment_file = $ENV{PWD} . "/.make_comment";
  unless (-e $cvs_comment_file) {
    $cvs_comment_file = "${ENV{HOME}}/comment_file";
  }
  open CVS, $cvs_comment_file;
  $cvscmt = <CVS>;
  close CVS;
  print "CVS comment is $cvscmt\n";

  # get filenames and versions.
  $cvs_list_file = $ARGV[0];
  unless (-e $cvs_list_file) {
    $cvs_list_file = "${ENV{HOME}}/cvs_list_file";
  }
  print "CVS file is $cvs_list_file\n";
  
  # Open and read in the files to add and commit.
  open CLF, $cvs_list_file or die "Can't open CVS list file. \n";
  @sccslist = <CLF>;
  close CLF;

  # Do a checkout on the uswbin dir first
  `cd $cvs_dir; cvs co usw/ce/uswbin`;

  foreach $ci_file (@sccslist) {
    chomp $ci_file;

    $sccsver = `vcwhat $ci_file | grep -v :`;
    print "sccsver is $sccsver\n";

    $sccsver =~ s{\A\s*|\s*\z}{}gmsx; # remove leading and trailing whitespace
    print "now it's $sccsver\n";

    ($filename, $filever) = split /\s+/, $sccsver;
    print "file name is $filename, version is $filever\n";

    qx(cp $filename $bin_dir);
    print "$filename to be commited at $filever version:\n";
    `cd $bin_dir; cvs add -k b $filename`;
    `cd $bin_dir; cvs commit -r $filever -m \"$cvscmt\"  $filename`;
    print "$filename commited $filever version:\n";
  }
#}
