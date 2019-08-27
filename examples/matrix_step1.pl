#!/usr/bin/perl
#
# monthly Matrix script to gather the monthly numbers form the 
# monthly forms.
#
# (]$[) matrix.pl:1.4 | CDATE=12/01/09 20:28:20

use Getopt::Std;
use Spreadsheet::WriteExcel;
use Spreadsheet::WriteExcel::Utility;

$zone = `uname -n`;
chomp $zone;

# Globals
$BILLDIR = "/$zone/usw/reports/monthly/billing";
@notgood = ("MX2", "RNH", "RV0", "RV2", "RV3", "RV4", "RV5", "RV6", 
	    "RV7", "RV8", "MCW", "MCY", "MCX", "HIW", "HIX", "HIY", 
	    "JKW", "JKY", "RTW", "RTX", "RTY", "XTW", "XTY",);

#Usage: matrix -m mmyy
#      -m mmyy, month year of billing reports to print
#      output: /$zone/usw/reports/monthly/matrix/matrix/matrix{mmyy}.csv,
#              comma delimited excel import file
#      output: /$zone/usw/reports/monthly/matrix/checklist{mmyy}.txt,
#              billing report check list
#      creates a matrix of billing data to be imported into excel 5.0

# usage function
sub usage() {
  print "Usage: $0 -m mmyy\n";
  print "      -m mmyy, month year of billing reports to print\n";
  print "      output: /$zone/usw/reports/monthly/matrix/matrix{mmyy}.csv,\n";
  print "              comma delimited excel import file\n";
  print "      output: /$zone/usw/reports/monthly/matrix/checklist{mmyy}.txt,\n";
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

$mybook_name = "/$zone/usw/reports/monthly/matrix/month" . $opt_m . ".xls";
my $workbook = Spreadsheet::WriteExcel->new('$mybook_name');
# Add a worksheet
$type_a_ws = $workbook->add_worksheet("Type A");
$type_b_ws = $workbook->add_worksheet("Type B");
$status_ws = $workbook->add_worksheet("Status Mods");

# Set the formatting
$global_format = Spreadsheet::WriteExcel::Format->new();
$global_format->set_color('black');
$global_format->set_font('Courier New');
$global_format->set_size(10);
$global_format->set_align('left');
$string_format  = $workbook->add_format();
$string_format->copy($global_format);

# Setup the headers in each worksheet
$type_a_ws->set_column('A:A', 37);
$type_a_ws->set_column('B:B', 47);
$type_a_ws->write('A1',"USW Type A HRS Name", $string_format);
$type_a_ws->write('B1',"USW Type A HRS Codes", $string_format);
$type_a_ws->write('C1',"1A", $string_format);
$type_a_ws->write('D1',"1P", $string_format);
$type_a_ws->write('E1',"AA", $string_format);
$type_a_ws->write('F1',"CMR", $string_format);
$type_a_ws->write('G1',"HDS", $string_format);
$type_a_ws->write('H1',"ITS", $string_format);
$type_a_ws->write('I1',"TPI", $string_format);
$type_a_ws->write('J1',"UA|1V|1C|1G", $string_format);
$type_a_ws->write('K1',"WB|MS", $string_format);
$type_a_ws->write('L1',"ALL", $string_format);
$type_a_ws->write('M1',"CHECKSUM", $string_format);

$type_b_ws->set_column('A:A', 60);
$type_b_ws->write('A1',"USW Type B HRS Codes", $string_format);
$type_b_ws->write('B1',"1A", $string_format);
$type_b_ws->write('C1',"1P", $string_format);
$type_b_ws->write('D1',"AA", $string_format);
$type_b_ws->write('E1',"CMR", $string_format);
$type_b_ws->write('F1',"HDS", $string_format);
$type_b_ws->write('G1',"ITS", $string_format);
$type_b_ws->write('H1',"TPI", $string_format);
$type_b_ws->write('I1',"UA|1V|1C|1G", $string_format);
$type_b_ws->write('J1',"WB|MS", $string_format);
$type_b_ws->write('K1',"ALL", $string_format);
$type_b_ws->write('L1',"CHECKSUM", $string_format);

$status_ws->set_column('A:A', 60);
$status_ws->write('A1',"USW Status Modifications", $string_format);
$status_ws->write('B1',"1A", $string_format);
$status_ws->write('C1',"1P", $string_format);
$status_ws->write('D1',"AA", $string_format);
$status_ws->write('E1',"CMR", $string_format);
$status_ws->write('F1',"HDS", $string_format);
$status_ws->write('G1',"ITS", $string_format);
$status_ws->write('H1',"TPI", $string_format);
$status_ws->write('I1',"UA|1V|1C|1G", $string_format);
$status_ws->write('J1',"WB|MS", $string_format);
$status_ws->write('K1',"ALL", $string_format);
$status_ws->write('L1',"CHECKSUM", $string_format);

# For the previous month pick up the files in the base
# directories.
if ($opt_m eq `/$zone/usw/offln/bin/pvmon`) {

  @dirlist = qx(ls -1 $BILLDIR/hrs/*$opt_m.bil \\
  $BILLDIR/gds/*$opt_m.bil $BILLDIR/hrsgds/*$opt_m.bil \\
  $BILLDIR/*$opt_m.bil);

} else {

  # If the month is an earlier one then pick up files
  # from yymm subdirectories.
  
  @dirlist = qx(ls -1 $BILLDIR/hrs/$ym/*$opt_m.bil \\
  $BILLDIR/gds/$ym/*$opt_m.bil $BILLDIR/hrsgds/$ym/*$opt_m.bil \\
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
      $con_hrs = $hrs_prt1[5] . $hrs_prt2[1];
      ($hrs, @rest) = split /\|/, $con_hrs;


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
  
  # Skip notgood connections for billing purposes.
  $skip = 0;
  foreach $ng (@notgood) {
    if ($ng eq $hrs) {
      $skip = 1;
    }
  }
  next if ($skip);

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
  $all_gds{$gds} = $gds;
  $hrs_nam{$hrs} = $con_hrs;
  $hrs_a{$hrs}{$gds} = $hrs_net_a;
  $hrs_b{$hrs}{$gds} = $hrs_net_b;
  $hrs_m{$hrs}{$gds} = $hrs_mod;

  close IFP;
}

# Open the config file and read in the HRS name.
$cfg_file = "</$zone/usw/reports/monthly/matrix/hrs_list.cfg";
open CFP, "$cfg_file";
while (<CFP>) {
  chomp;
  ($hrs_name, $hrs_main) = split /=/;
  $hrs_full{$hrs_main} = $hrs_name;
}
close CFP;

# Now for printing...
# Open up an output file, complete with name taken from the command line
# and make it the primary output buffer. So from now on any print that
# I do will go to this file and not STDEV
$OFP = ">/$zone/usw/reports/monthly/matrix/matrix" . $opt_m . ".csv";
open OFP or die "Can't open output file.";
select OFP; $| = 1;

# Now we need to go through the all_gds hash and load them into
# and array structure so we get them in the order we want. The
# ALL member must be entered last to make the repots look right.
$gds_cnt = 0;
$header = "";
$type_header = "Type A HRS Name , HRS Chain ,";
for $gdsn ( sort keys %all_gds ) {
  if ($gdsn ne "ALL") {
    $gds_lst[$gds_cnt++] = $gdsn;
    $header .= "$gdsn,";
  }
}
# After other GDS's, put ALL on the end.
$gds_lst[$gds_cnt] = $all_gds{ALL};
$header .= "ALL";

$row = 2;     # Keep track of row and column
$col = 0;     # Keep track of row and column

# Print the Type A net bookings for HRS's.
printf "%s%s\n", $type_header, $header;
foreach $hotel ( sort keys %hrs_a ) {

  # Save the ALL entry for last.
  if ($hotel ne "ALL") {
    $hrs_full_print = $hrs_full{$hotel} ? $hrs_full{$hotel} : "notavailable";
    $type_a_ws->write($row, $col++, $hrs_full_print, $string_format);

    printf "\n%s,%s", $hrs_full_print, $hrs_nam{$hotel};
    $type_a_ws->write($row, $col++, $hrs_name{$hotel}, $string_format);
    foreach $gdsn ( @gds_lst ) {
      $this_gds_numb = $hrs_a{$hotel}{$gdsn} ? $hrs_a{$hotel}{$gdsn} : "0";
      printf ",%s", $this_gds_numb;
      $type_a_ws->write($row, $col++, $this_gds_numb, $string_format);
    }
    $start_sum = xl_rowcol_to_cell($row, 2);
    $end_sum = xl_rowcol_to_cell($row, $col - 2);
    print "$row, $col++, =SUM($start_sum:$end_sum)";
    $last_row = $row;         # Save off the last row not ALL
  }
  $row++;
  $col = 0;
}

# After other HRS's, put ALL
printf"\n,ALL";
$col = 1;			# Skip past the 0 column
$type_a_ws->write($row, $col++, "ALL", $string_format);
foreach $gdsn ( @gds_lst ) {
  $all_gds_num = $hrs_a{ALL}{$gdsn} ? $hrs_a{ALL}{$gdsn} : "0";
  printf",%s ", $all_gds_num; 
  $type_a_ws->write($row, $col++, $all_gds_num, $string_format);
}
print "\n\n\n";

$row++;
$col = 1;			# Skip past the 0 column
# Now for the spreadsheet make a CHECKSUM row
$type_a_ws->write($row, $col++, "CHECKSUM", $string_format);
for (; $col < 13; $col++) {
  $start_sum = xl_rowcol_to_cell(2, $col);
  $end_sum = xl_rowcol_to_cell($last_row, $col);
  print "$row, $col++, =SUM($start_sum:$end_sum)";
}


# Print B header and use GDS array to print GDS header
$type_header = "USW Type B Billing,";
printf "%s%s\n", $type_header, $header;

$row = 1;     # Keep track of row and column
$col = 0;     # Keep track of row and column

# Print the Type B net bookings.
foreach $hotel ( sort keys %hrs_b ) {

  # Save the ALL entry for last.
  if ($hotel ne "ALL") {
    printf "\n%s", $hrs_nam{$hotel};
    $type_b_ws->write($row, $col++, $hrs_name{$hotel}, $string_format);

    foreach $gdsn ( @gds_lst ) {
      $this_gds_numb = $hrs_b{$hotel}{$gdsn} ? $hrs_b{$hotel}{$gdsn} : "0";
      printf ",%s", $this_gds_numb;
      $type_b_ws->write($row, $col++, $this_gds_numb, $string_format);
    }
    # Make a checksum column at the end.
    $start_sum = xl_rowcol_to_cell($row, 1);
    $end_sum = xl_rowcol_to_cell($row, $col - 2);
    print "$row, $col++, =SUM($start_sum:$end_sum)";
    $last_row = $row;         # Save off the last row not ALL
  }
  $row++;
  $col = 0;
}
# After other HRS's, put ALL at the end.
printf"\nALL";
$type_b_ws->write($row, $col++, "ALL", $string_format);
foreach $gds_a ( @gds_lst ) {
  $all_gds_num = $hrs_b{ALL}{$gds_a} ? $hrs_b{ALL}{$gds_a} : "0";
  printf",%s", $all_gds_num;
  $type_b_ws->write($row, $col++, $all_gds_num, $string_format);
}
printf "\n\n\n";

$row++;
$col = 0;
# Now for the spreadsheet make a CHECKSUM row
$type_b_ws->write($row, $col++, "CHECKSUM", $string_format);
for (; $col < 13; $col++) {
  $start_sum = xl_rowcol_to_cell(1, $col);
  $end_sum = xl_rowcol_to_cell($last_row, $col);
  print "$row, $col++, =SUM($start_sum:$end_sum)";
}


# Print Mod header and use GDS array to print GDS header
$type_header = "USW Status Modifications,";
printf "%s%s\r\n", $type_header, $header;

$row = 1;     # Keep track of row and column
$col = 0;     # Keep track of row and column

# Print the net Status Modifications.
foreach $hotel ( sort keys %hrs_m ) {

  # Save the ALL entry for last.
  if ($hotel ne "ALL") {
    printf "\n%s", $hrs_nam{$hotel};
    $status_ws->write($row, $col++, $hrs_name{$hotel}, $string_format);

    foreach $gdsn ( @gds_lst ) {
      $this_gds_numb = $hrs_m{$hotel}{$gdsn} ? $hrs_m{$hotel}{$gdsn} : "0";
      printf",%s", $this_gds_numb;
      $status_ws->write($row, $col++, $this_gds_numb, $string_format);
    }

    # Make a checksum column at the end.
    $start_sum = xl_rowcol_to_cell($row, 1);
    $end_sum = xl_rowcol_to_cell($row, $col - 2);
    print "$row, $col++, =SUM($start_sum:$end_sum)";
    $last_row = $row;         # Save off the last row not ALL
  }
  $row++;
  $col = 0;
}
# After other HRS's, put ALL at the end.
printf"\nALL";
$status_ws->write($row, $col++, "ALL", $string_format);
foreach $gdsn ( @gds_lst ) {
  $all_gds_num = $hrs_m{ALL}{$gdsn} ? $hrs_m{ALL}{$gdsn} : "0";
  printf",%s", $all_gds_num;
  $status_ws->write($row, $col++, $all_gds_num, $string_format);
}
printf "\n";

$row++;
$col = 0;
# Now for the spreadsheet make a CHECKSUM row
$status_ws->write($row, $col++, "CHECKSUM", $string_format);
for (; $col < 13; $col++) {
  $start_sum = xl_rowcol_to_cell(1, $col);
  $end_sum = xl_rowcol_to_cell($last_row, $col);
  print "$row, $col++, =SUM($start_sum:$end_sum)";
}

close OFP;
$workbook->close();


