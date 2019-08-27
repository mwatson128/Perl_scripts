#!/usr/bin/perl
#
# monthly Matrix script to gather the monthly numbers form the 
# monthly forms.
#
# (]$[) matrix.pl:1.3 | CDATE=01/18/05 15:44:12


use Getopt::Std;

# Globals
$BILLDIR = "/uswsup01/usw/reports/monthly/billing";

#Usage: matrix -m mmyy
#      -m mmyy, month year of billing reports to print
#      output: /usw/reports/monthly/matrix/matrix/matrix{mmyy}.csv,
#              comma delimited excel import file
#      output: /usw/reports/monthly/matrix/checklist{mmyy}.txt,
#              billing report check list
#      creates a matrix of billing data to be imported into excel 5.0

# usage function
sub usage() {
  print "Usage: $0 -m mmyy\n";
  print "      -m mmyy, month year of billing reports to print\n";
  print "      output: /usw/reports/monthly/matrix/matrix{mmyy}.csv,\n";
  print "              comma delimited excel import file\n";
  print "      output: /usw/reports/monthly/matrix/checklist{mmyy}.txt,\n";
  print "              billing report check list\n";
  print "      creates a \"matrix\" of billing data to be imported\n";
  print "      into excel\n\n";
} # end of function

getopt('m:');

$ARGC = @ARGV;

# Process month from the command line argument
if ($opt_m) {

  if ( 2 <= $ARGC) {
    print "More than one argument found, using first\n";
  }
  if ($opt_m =~ /\d\d\d\d/) {
    # Turn mmyy around to yymm. (That's how the archive directories are named) 
    @parts = split //, $opt_m;
    $ym = sprintf("%d%d%d%d", $parts[2], $parts[3], $parts[0], $parts[1]);
  } else {
    print "Invalid nondecimal argument: $cmdln[0]\n";
    usage();
    exit;
  }
  
} else {

  usage();
  exit;
}

# For the previous month pick up the files in the base
# directories.
if ($opt_m eq `/uswsup01/usw/offln/bin/pvmon`) {

  @dirlist = qx(ls -1 $BILLDIR/hrs2/*$opt_m.bil \\
  $BILLDIR/gds/*$opt_m.bil $BILLDIR/hrs2gds/*$opt_m.bil \\
  $BILLDIR/*$opt_m.bil);

  @poslst = qx(ls -1 $BILLDIR/hrs/*$opt_m.bil);
  foreach $lst (@poslst) {
    $hrsln = qx(grep "Hotel Reservation System" $lst);
    @shrt = split /: /, $hrsln;
    @schns = split /\|/, $shrt[1];
    $nschns = @schns;
    if (1 == $nschns) {
      push @dirlist, $lst;
    }
  }

  @poslst = qx(ls -1 $BILLDIR/hrsgds/*$opt_m.bil);
  foreach $lst (@poslst) {
    $hrsln = qx(grep "Hotel Reservation System" $lst);
    @shrt = split /: /, $hrsln;
    @schns = split /\|/, $shrt[1];
    $nschns = @schns;
    if (1 == $nschns) {
      push @dirlist, $lst;
    }
  }

} else {

  # If the month is an earlier one then pick up files
  # from yymm subdirectories.
  
  @dirlist = qx(ls -1 $BILLDIR/hrs2/$ym/*$opt_m.bil \\
  $BILLDIR/gds/$ym/*$opt_m.bil $BILLDIR/hrs2gds/$ym/*$opt_m.bil \\
  $BILLDIR/$ym/*$opt_m.bil);

}


# For each of the files we found above, look through them
# for billing information.
foreach $ifile (@dirlist) {

  open IFP, "$ifile";

  while (<IFP>) {
    
    chomp;
    if (/Global/) {

      @glbl = split / +/;
      $gds = $glbl[4];
    } elsif (/Hotel/) {

      $frst = $_;
      @hrs_prt1 = split / +/, $frst;
      $scnd = <IFP>;
      chomp $scnd;
      if (/\w/) {
        @hrs_prt2 = split / +/, $scnd;
      }
      $hrs = $hrs_prt1[5] . $hrs_prt2[1];

    } elsif (/Total Type A Net/) {
    
      $_ =~ /(-*\d+)/; 
      $hrs_net_a = $1;

    } elsif (/Total Type B Net/) {
    
      $_ =~ /(-*\d+)/;
      $hrs_net_b = $1;

    } elsif (/Total Status Modifications/) {

      $_ =~ /(-*\d+)/;
      $hrs_mod = $1;
    }
  }

  # Collect all of the numbers we just found into hashes and
  # hashed hashes.
  # 
  # Variables:
  # all_gds	- hash that collects unique GDS's.
  # hrs_a	- double hash, collects type A net bookings
  #		by GDS, by HRS.
  # hrs_b	- double hash, collects type B net bookings
  #		by GDS, by HRS.
  # hrs_c	- double hash, collects Status Modifications 
  #		by GDS, by HRS.
  # Below checks for dups among subchains for GDS 1P
  #if ($gds eq "1P") {
    #if (!$hrs_a{$hrs}) {
      #$hrs_a{$hrs} = $hrs_net_a;
    #}
    #else {
      #print "Found dup at $hrs";
    #}
  #}

  $all_gds{$gds} = $gds;
  $hrs_a{$hrs}{$gds} = $hrs_net_a;
  $hrs_b{$hrs}{$gds} = $hrs_net_b;
  $hrs_m{$hrs}{$gds} = $hrs_mod;
  

  close IFP;
}

# We must take care of the RAVE Hotels... they handle AALSRQ's so will
# Never have any bookings and just take up space, so we're getting rid
# of them.
delete $hrs_a{RV2};
delete $hrs_a{RV3};
delete $hrs_a{RV4};
delete $hrs_a{RV5};
delete $hrs_a{RV6};
delete $hrs_a{RV7};
delete $hrs_a{RV8};
delete $hrs_a{RV9};
delete $hrs_a{RV0};
delete $hrs_b{RV2};
delete $hrs_b{RV3};
delete $hrs_b{RV4};
delete $hrs_b{RV5};
delete $hrs_b{RV6};
delete $hrs_b{RV7};
delete $hrs_b{RV8};
delete $hrs_b{RV9};
delete $hrs_b{RV0};
delete $hrs_m{RV2};
delete $hrs_m{RV3};
delete $hrs_m{RV4};
delete $hrs_m{RV5};
delete $hrs_m{RV6};
delete $hrs_m{RV7};
delete $hrs_m{RV8};
delete $hrs_m{RV9};
delete $hrs_m{RV0};

# Now for printing...
# Open up an output file, complete with name taken from the command line
# and make it the primary output buffer. So from now on any print that
# I do will go to this file and not STDEV
$OFP = ">/uswsup01/usw/reports/monthly/matrix/matrix_ch" . $opt_m . ".csv";
open OFP or die "Can't open output file.";
select OFP; $| = 1;

# Now we need to go through the all_gds hash and load them into
# and array structure so we get them in the order we want. The
# ALL member must be entered last to make the repots look right.
$gds_cnt = 0;
$header = "";
$type_header = "USW Type A Billing,";
for $gdsn ( sort keys %all_gds ) {
  if ($gdsn ne "ALL") {
    $gds_lst[$gds_cnt++] = $gdsn;
    $header .= "$gdsn,";
  }
}
# After other GDS's, put ALL on the end.
$gds_lst[$gds_cnt] = $all_gds{ALL};
$header .= "ALL";

# Print the Type A net bookings for HRS's.
printf "%s%s\n", $type_header, $header;
foreach $hotel ( sort keys %hrs_a ) {

  # Save the ALL entry for last.
  if ($hotel ne "ALL" ) {
    printf "\n$hotel";
    foreach $gdsn ( @gds_lst ) {
      printf ",%s", $hrs_a{$hotel}{$gdsn} ? $hrs_a{$hotel}{$gdsn} : "0";
    }
  }
}
# After other HRS's, put ALL at the end.
printf"\nALL ";
foreach $gdsn ( @gds_lst ) {
  printf",%s ", $hrs_a{ALL}{$gdsn} ? $hrs_a{ALL}{$gdsn} : "0";
}
print "\n\n\n";

# Print B header and use GDS array to print GDS header
$type_header = "USW Type B Billing,";
printf "%s%s\n", $type_header, $header;

# Print the Type B net bookings.
foreach $hotel ( sort keys %hrs_b ) {

  # Save the ALL entry for last.
  if ($hotel ne "ALL") {
    printf "\n$hotel";
    foreach $gdsn ( @gds_lst ) {
      printf ",%s", $hrs_b{$hotel}{$gdsn} ? $hrs_b{$hotel}{$gdsn} : "0";
    }
  }
}
# After other HRS's, put ALL at the end.
printf"\nALL ";
foreach $gds_a ( @gds_lst ) {
  printf",%s", $hrs_b{ALL}{$gds_a} ? $hrs_b{ALL}{$gds_a} : "0";
}
printf "\n\n\n";


# Print Mod header and use GDS array to print GDS header
$type_header = "USW Status Modifications,";
printf "%s%s\n", $type_header, $header;

# Print the net Status Modifications.
foreach $hotel ( sort keys %hrs_m ) {

  # Save the ALL entry for last.
  if ($hotel ne "ALL") {
    printf "\n$hotel";
    foreach $gdsn ( @gds_lst ) {
      printf",%s", $hrs_m{$hotel}{$gdsn} ? $hrs_m{$hotel}{$gdsn} : "0";
    }
  }
}
# After other HRS's, put ALL at the end.
printf"\nALL ";
foreach $gdsn ( @gds_lst ) {
  printf",%s", $hrs_m{ALL}{$gdsn} ? $hrs_m{ALL}{$gdsn} : "0";
}
printf "\n";

close OFP;
