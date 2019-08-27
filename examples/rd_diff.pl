#!/bin/perl
# (]$[) %M%:%I% | CDATE=%G% %U%

# Initialize values.
$pwd = ${ENV{PWD}};
$vcs = ${ENV{PWD}};

# derive the directory names.
($slash, $rootd, $sandb, @rest) = split /\//, $pwd;

if ("uswdev" ne $rootd) {
  die "For use in the /uswdev directory only!\n";
}

$sccsdir1 = sprintf("/vc/sccs/%s/%s", $sandb, join ("/", @rest));
$usw_sccsdir = sprintf("/vc/sccs/usw/%s", join ("/", @rest));
$usw_dir = sprintf("/uswdev/usw/%s", join ("/", @rest));

# Get c files and rd file names for this dir.
@r_names = `ls -1 ${sccsdir1}/s.*.rd`;

foreach $nm (@r_names) {
  chomp $nm;
  ($workdir, $file) = split /s\./, $nm;
  $utf8_file{$file} = $file;
}

# Make hash of the version diffs 
foreach $fl (sort keys %utf8_file) {

  print "\nFILE is $fl :\n";
  $back_num = 0;

  @vcdiff = `/tools/bin/ckprs $fl`; 
  shift @vcdiff;

  foreach $ln (@vcdiff) {
    chomp $ln;

    next if ($ln =~ /^MRs|^COMMENT|^XREF|^VCS/);
    next if ($ln =~ /^$/);

    if ($ln =~ /^D /) {
      # First line of version entry.
      ($d, $ver, $dt, $hms, $user, @rest) = split / /, $ln;
      $back_num++;
      print "\n  $ver - $dt $hms - $user\n" if ($back_num < 13);
    }
    else {
      print "  $ln\n" if ($back_num < 13);
    }
  }
}

# Compare the version diffs to see how much is different.



# Output the diffs.



