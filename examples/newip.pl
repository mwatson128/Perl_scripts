#!/usr/bin/perl

$ARGC = @ARGV;
if ($ARGC == 4) {
  $chain=$ARGV[0];
  $brand=$ARGV[1];
  $oldchain=$ARGV[2];
  $oldbrand=$ARGV[3];
}
else {
  print "usage: newip.pl newchain newbrand oldchain oldbrand \n";
  exit 0;
}

$lc_nc = lc $chain;
$lc_nb = lc $brand;
$lc_oc = lc $oldchain;
$lc_ob = lc $oldbrand;

# Build the directory structure.
qx(mkdir /usw/src/ip2/$lc_nc);

qx(cp -R /usw/src/ip2/$lc_oc/* /usw/src/ip2/$lc_nc/);

# Remove the version control files
`rm -rf /usw/src/ip2/$lc_nc/a/sccs/*`;
`rm -rf /usw/src/ip2/$lc_nc/b/sccs/*`;

@files = `ls -d /usw/src/ip2/$lc_nc/a/*`;
search_files(@files);

@files = `ls -d /usw/src/ip2/$lc_nc/b/*`;
search_files(@files);


sub search_files {

  foreach $file (@_) {
    chomp $file;
    print $file, "\t\t";

    if ( -d $file) {

      @subfiles = `ls $file/*`;
      print "is a Directory! \n";
      foreach $subfile (@subfiles) {
          print "   ----  $subfile \n";
      }
    }
  
    if ( -T $file) {

      print "is a Text file! \n";
      `chmod 664 $file`;

      `sed s/$oldchain/$newchain/g $file > hold`;
      `mv -f hold $file`;

      `sed s/$oldbrand/$brand/g $file > hold`;
      `mv -f hold $file`;

      `sed s/$lc_oc/$lc_nc/g $file > hold`;
      `mv -f hold $file`;

      `sed s/$lc_ob/$lc_nb/g $file > hold`;
      `mv -f hold $file`;

    }
  }
}


