#!/bin/perl 
# (]$[) %M%:%I% | CDATE=%G% %U%

# Initialize values.
$pwd = ${ENV{PWD}};

qx(rm -f ${pwd}/*.c);
#print "\nrm -f ${pwd}/*.c\n";

# derive the directory names.
($slash, $rootd, $sandb, @rest) = split /\//, $pwd;

if ("uswdev" ne $rootd) {
  die "For use in the /uswdev directory only!\n";
}

$rest[1] = "ip3";
$ip3_sccsdir = sprintf("/vc/sccs/%s/%s", $sandb, join ("/", @rest));
$ip3_dir = sprintf("%s", join ("/", @rest));
$rest[1] = "ip2";
$ip2_sccsdir = sprintf("/vc/sccs/%s/%s", $sandb, join ("/", @rest));
$ip2_dir = sprintf("%s", join ("/", @rest));

$type_dir = pop @rest;

# Get c files and rd file names for the USW dir.
@u_names = `ls -1 ${ip2_sccsdir}/s.*.c`;

foreach $nm (@u_names) {
  chomp $nm;
  ($workdir, $file) = split /${type_dir}\/s\./, $nm;
  $utf8_file{$file} = $file;
}

# Make hash of the version diffs 
foreach $fl (sort keys %utf8_file) {

  #print "\nFILE is $fl :\n";
  $n_fl = $fl; 
  $n_fl =~ s/2a.c/3a.c/g;
  $td = `mv ${ip2_sccsdir}/s.${fl} ${ip3_sccsdir}/s.${n_fl}`;
  #print "mv ${ip2_sccsdir}/s.${fl} ${ip3_sccsdir}/s.${n_fl}\n";
  qx(/tools/bin/ckget $n_fl);
  qx(touch *);
}



