#!/bin/perl
# (]$[) %M%:%I% | CDATE=%G% %U%

# Initialize values.
$pwd = ${ENV{PWD}};

# derive the directory names.
($slash, $rootd, $sandb, @rest) = split /\//, $pwd;

if ("uswdev" ne $rootd) {
  die "For use in the /uswdev directory only!\n";
}

$sccsdir1 = sprintf("/vc/sccs/%s/%s", $sandb, join ("/", @rest));
$usw_sccsdir = sprintf("/vc/sccs/usw/%s", join ("/", @rest));
$usw_dir = sprintf("/uswdev/usw/%s", join ("/", @rest));

$type_dir = pop @rest;

# Get c files and rd file names for this dir.
@tc_names = `ls -1 ${sccsdir1}/s.*.c`;
@tr_names = `ls -1 ${sccsdir1}/s.*.rd`;

# Get c files and rd file names for the USW dir.
@uc_names = `ls -1 ${usw_sccsdir}/s.*.c`;
@ur_names = `ls -1 ${usw_sccsdir}/s.*.rd`;

foreach $nm (@tc_names) {
  chomp $nm;
  ($workdir, $file) = split /${type_dir}\/s\./, $nm;
  $utf8_file{$file} = $file;
}
foreach $nm (@tr_names) {
  chomp $nm;
  ($workdir, $file) = split /${type_dir}\/s\./, $nm;
  $utf8_file{$file} = $file;
}

# Make hash of the version diffs 
foreach $fl (sort keys %utf8_file) {

  print "\nFILE is $fl :\n";
  
  $td = `diff ${sccsdir1}/s.${fl} ${usw_sccsdir}/s.${fl}`;
  #print "diff ${sccsdir1}/s.${fl} ${usw_sccsdir}/s.${fl}\n";

  if ($td) {
    print "  The files differ.\n";
  }
  else {
    print "  None\n";
  }
}

# Compare the version diffs to see how much is different.



# Output the diffs.



