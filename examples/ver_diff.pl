#!/bin/perl
# (]$[) %M%:%I% | CDATE=%G% %U%

# Initialize values.
$pwd = ${ENV{PWD}};

# derive the directory names.
($slash, $rootd, $sandb, @rest) = split /\//, $pwd;

if ("uswdev" ne $rootd) {
  die "For use in the /uswdev directory only!\n";
}

$sccsdir[0] = sprintf("/vc/sccs/%s/%s", $sandb, join ("/", @rest));
$sccsdir[1] = sprintf("/vc/sccs/usw/%s", join ("/", @rest));

$sub_dir = pop @rest;

$ofp[0] = sprintf(">/uswdev/usw_utf8/%s/utf8_diff_%s.txt", 
                  join ("/", @rest), $sub_dir);
$ofp[1] = sprintf(">/uswdev/usw_utf8/%s/usw_diff_%s.txt", 
                  join ("/", @rest), $sub_dir);

for($i = 0; $sccsdir[$i]; $i++) {

  print "In sccsdir $i \n";
  # Get c files and rd file names for this dir.
  @c_names = `ls -1 ${sccsdir[$i]}/s.*.c`;
  @r_names = `ls -1 ${sccsdir[$i]}/s.*.rd`;

  foreach $nm (@c_names) {
    chomp $nm;
    ($workdir, $file) = split /s\./, $nm;
    $cur_file{$file} = $file;
  }
  foreach $nm (@r_names) {
    chomp $nm;
    ($workdir, $file) = split /s\./, $nm;
    $cur_file{$file} = $file;
  }
  
  open OFP, $ofp[$i] or die "Can't open $ofp[$i]";

  # Make hash of the version diffs 
  foreach $fl (sort keys %cur_file) {

    printf OFP "\nFILE is $fl :\n";
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
	printf OFP "\n  $ver - $dt $hms - $user\n" if ($back_num < 13);
      }
      else {
	printf OFP "  $ln\n" if ($back_num < 13);
      }
    }
  }
  close OFP;
}

# Compare the version diffs to see how much is different.



# Output the diffs.



