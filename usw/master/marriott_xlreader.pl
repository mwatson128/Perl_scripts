#!/usr/bin/perl

use lib '/home/usw/perl5lib';
use Getopt::Long;
use Spreadsheet::ParseExcel;

sub usageexit;

@fields = qw(2 5 8 11 14 17 20 23 26 29 32 35 38
             41 44 47 50 53 56);
@prevNames = qw(2 6 10 14 18 22 26 30 34 38 42 46 50 54 58 62);

%fieldNames = (
  2 => "CITY TAX",
  5 => "CRIB",
  8 => "EXTRA PERSON CHARGE",
  11 => "GOODS & SERVICES TAX",
  14 => "CONVENTION/TOURISM",
  17 => "OCCUPANCY TAX",
  20 => "RESORT FEE",
  23 => "ROLLAWAY",
  26 => "SERVICE CHARGE",
  29 => "STATE TAX",
  32 => "VAT - VALUE ADDED TAX",
  35 => "COUNTY TAX",
  38 => "ASSESSMENT FEE",
  41 => "NON REFUNDABLE PET SANITATION FEE",
  44 => "REFUNDABLE PET SANITATION FEE",
  47 => "STATE COST RECOVERY FEE",
  50 => "DESTINATION AMENITY FEE",
  53 => "HOTEL - MOTEL FEE",
  56 => "LOCAL FEE",
);

$totalRowsProcessed = 0;
$totalRowsPrinted = 0;
$extraPersonChargeRows = 0;
$resortFeeRows = 0;
$extraPersonResortFeeRows = 0;

GetOptions (
  'p|prev=s' => \$prevFile,
  'n|new=s'  => \$newFile,
  'h|help=s' => \$helpCmd
);

if ($helpCmd) {
  usageexit();
}

if ($newFile) {
  chomp $newFile;
}
else {
  usageexit();
}

open LOG, ">> marriott_rates.log" or die " Can't open previous file\n";

chomp ($thisDate = `date`);
print LOG "\n";
print LOG "=" x 70;
print LOG "\n  Beginning Marriott spreadsheet loader at $thisDate \n";

print "Working... \n";

my $parser   = Spreadsheet::ParseExcel->new();
my $workbook = $parser->parse( $newFile );

if ( !defined $workbook ) {
    die "Parsing error: ", $parser->error(), ".\n";
}

# Read in the previous file.
if ($prevFile) {
  qx(cp $prevFile ${prevFile}-);
  open IFP, $prevFile or die " Can't open previous file\n";
  # Read in prevFile
  while (<IFP>) {
    chomp;
    @res1 = split /\|/;

    $res1[0] =~ s/(^\s+|\s+$)//g;
    $totalKey = $res1[0] . "_" .  $res1[1];
    $prevTotal++;

    foreach $namePos (@prevNames) {
      $thisPos = $namePos;
      $compString = uc $res1[$namePos];
      next unless $compString;
      foreach $key (sort keys %fieldNames) {
        if ($compString eq $fieldNames{$key}) {
	  $arrayPos = $key;
	  last;
	}
      }

      if ($res1[$thisPos++]) {

	if ($prevPosCnt[$arrayPos]) {
	  $prevPosCnt[$arrayPos]++;
	}
	else {
	  $prevPosCnt[$arrayPos] = 1;
	}
      }

      $totalHash{$totalKey}[$arrayPos++] = $res1[$thisPos++];
      $totalHash{$totalKey}[$arrayPos++] = $res1[$thisPos++];
      $totalHash{$totalKey}[$arrayPos++] = $res1[$thisPos];
    }
  }

  $prevEPCnt = $prevPosCnt[8];
  $prevRFCnt = $prevPosCnt[20];

  print LOG "\n    - Reading in previous config file: \n";
  print LOG "\n    ***********************************************\n";
  print LOG "    ** Total rows loaded              = $prevTotal\n";
  print LOG "    ** Extra Person Charge Rows       = $prevEPCnt\n";
  print LOG "    ** Resort Fee Rows                = $prevRFCnt\n";
  print LOG "    ***********************************************\n";
  chomp ($thisDate = `date`);
  print LOG "\n    - Finished reading previous config file at $thisDate \n";

}

# Read in the spreadsheet given in -n
$updateTotal = 0;

$worksheet = $workbook->worksheet('Weekly');
$op1Cnt = 0;

my ( $row_min, $row_max ) = $worksheet->row_range();
my ( $col_min, $col_max ) = $worksheet->col_range();
print "$worksheet->{Name} Number of Columns: $col_max\n";

$row = 0;
$totalRowsProcessed++;
for $col ( $col_min .. $col_max ) {
  $cell = $worksheet->get_cell( $row, $col );
  if (defined $cell) {
    $colHeadersArray[$col] = $cell->value();
  }
}
$row_min = 1;

for $row ( $row_min .. $row_max ) {

  $totalRowsProcessed++;
  $bcell = $worksheet->get_cell( $row, 0 );
  next unless ( $bcell );
  $mcell = $worksheet->get_cell( $row, 1 );
  next unless ( $mcell );
  $brandCell = $bcell->value();
  $brandCell =~ s/(^\s+|\s+$)//g;
  $marshaCell = $mcell->value();
  $marchaCell =~ s/(^\s+|\s+$)//g;
  $mainHashKey = $brandCell . "_" . $marshaCell;

  foreach $num ( @fields ) {
    $col = int $num;
    $rawCell = $worksheet->get_cell( $row, $col );
    if ( $rawCell ) {

      $vcell = $rawCell->value();
      # remove extra while space
      $vcell =~ s/(^\s+|\s+$)//g;

      # Make values M or P
      $vcell =~ s/$/M/;
      $vcell =~ s/pcM/P/;
      next if ( $vcell eq "M" );

      $updateTotal++;
      $cntKey = $colHeadersArray[$col];
      # Keep a count of the number of these
      if ($curPosCnt[$num]) {
	$curPosCnt[$num]++;
      }
      else {
	$curPosCnt[$num] = 1;
      }

      $c_1 = $col + 1;
      $c_2 = $col + 2;

      $cell_1 = $worksheet->get_cell( $row, $c_1 );
      if ( $cell_1 ) {
	$vcell_1 = $cell_1->value();
	$vcell_1 =~ s/(^\s+|\s+$)//g;
      }
      else {
	$vcell_1 = "";
      }

      $cell_2 = $worksheet->get_cell( $row, $c_2 );
      if ( $cell_2 ) {
	$vcell_2 = $cell_2->value();
	$vcell_2 =~ s/(^\s+|\s+$)//g;
      }
      else {
	$vcell_2 = "";
      }

      $upDateHash{$mainHashKey}[$col] = "$vcell";
      $upDateHash{$mainHashKey}[$c_1] = "$vcell_1";
      $upDateHash{$mainHashKey}[$c_2] = "$vcell_2";
    }
  }
}


if ($curPosCnt[8]) {
  $curEPCnt = $curPosCnt[8];
} else {
  $curEPCnt = 0;
}
if ($curPosCnt[20]) {
  $curRFCnt = $curPosCnt[20];
} else {
  $curRFCnt = 0;
}

print LOG "    - Reading in update spreadsheet file: \n";
print LOG "\n    ***********************************************\n";
print LOG "    ** Total rows loaded              = $updateTotal\n";
print LOG "    ** Extra Person Charge Rows       = $curEPCnt\n";
print LOG "    ** Resort Fee Rows                = $curRFCnt\n";
print LOG "    ***********************************************\n";

chomp ($thisDate = `date`);
print LOG "\n    - Finished reading spreadsheet file at $thisDate \n";
print LOG "    - Appling updates from spreadsheet to config file.\n";

# Go through the update hash and apply to the total Hash.
$numUpdates = 0;
foreach $key (sort keys %upDateHash) {

  ($brand, $marsha) = split /_/, $key;

  # Update if field 8 or 20 are present.
  if ($upDateHash{$key}[8] || $upDateHash{$key}[20]) {
    foreach $num ( @fields ) {
      $totalHash{$key}[$num] = $upDateHash{$key}[$num];
      $num_1 = $num + 1;
      $totalHash{$key}[$num_1] = $upDateHash{$key}[$num_1];
      $num_2 = $num + 2;
      $totalHash{$key}[$num_2] = $upDateHash{$key}[$num_2];
    }
    $numUpdates++;
  }
  # We need to remove this one if present in totalHash
  elsif ($totalHash{$key}) {
    delete $totalHash{$key};
  }
  # If the PID doesn't have 8 or 20 and it's not in the totalHash,
  # we do nothing.
}

if ($numUpdates) {
  print LOG "      Processed $numUpdates updates to the config.\n";
}
else {
  print STDERR "\n    ********************************************************\n";
  print STDERR "    ** WARNING! Processed 0 updates to the config.  WARNING!\n";
  print STDERR "    ** This means there was no change to the config from \n";
  print STDERR "    ** this update.  Make sure this is the expected result!";
  print STDERR "\n    ********************************************************\n";

  print LOG "\n    ********************************************************\n";
  print LOG "    ** WARNING! Processed 0 updates to the config.  WARNING!\n";
  print LOG "    ** This means there was no change to the config from \n";
  print LOG "    ** this update.  Make sure this is the expected result!";
  print LOG "\n    ********************************************************\n";
}

print LOG "    - completed applying updates from spreadsheet ... \n\n";
print LOG "    - Updated the config file ... \n";
$output = "> marriott_fees.cfg";
open OFP, $output or die " Can't open OFP\n";

$found_8 = 0;
$found_20 = 0;
$eprfCnt = 0;
$rfCnt = 0;
$epcCnt =0;
$totalRowsUpdated = 0;
foreach $key (sort keys %totalHash) {
  ($brand, $marsha) = split /_/, $key;
  $op1 = "$brand|$marsha|";
  foreach $num ( @fields ) {

    $num_1 = $num + 1;
    $num_2 = $num + 2;

    if ($totalHash{$key}[$num] &&
        $totalHash{$key}[$num_1] &&
        $totalHash{$key}[$num_2]) {

      $op1 .= "$fieldNames{$num}|";
      $op1 .= "$totalHash{$key}[$num]|";
      $op1 .= "$totalHash{$key}[$num_1]|";
      $op1 .= "$totalHash{$key}[$num_2]|";
    }
  }

  if ($op1 =~ /EXTRA PERSON CHARGE/) {
    $epcCnt++;
    $found_8 = 1;
  }
  if ($op1 =~ /RESORT FEE/) {
    $rfCnt++;
    $found_20 = 1;
  }

  if ($found_8 || $found_20) {
    print OFP "$op1\n";
    $totalRowsUpdated++;
  }
  if ($found_8 && $found_20) {
    $eprfCnt++;
  }

  $found_8 = 0;
  $found_20 = 0;
}

close OFP;

print LOG "\n    ***********************************************\n";
print LOG "    ** Total rows processed           = $totalRowsUpdated\n";
print LOG "    ** Extra Person Charge Rows       = $epcCnt\n";
print LOG "    ** Resort Fee Rows                = $rfCnt\n";
print LOG "    ** Extra Person + Resort Fee Rows = $eprfCnt\n";
print LOG "    ***********************************************\n";
chomp ($thisDate = `date`);
print LOG "\n  Finished Marriott spreadsheet loader at $thisDate \n";
print LOG "=" x 70;
print LOG "\n";

close LOG;
print "Finished.  You can find the a log in the file marriott_rates.log\n";

#####################################################################
## Usage printing function
##
#####################################################################
sub usageexit() {

  print STDERR "\nUsage: xlreader [options] \n";
  print STDERR "  converts the spreadsheet into a config file. \n";
  print STDERR "  Options:\n";
  print STDERR "  -p filename  = Previous file name to start off with. \n";
  print STDERR "  -n filename  = New filename with update to apply. \n";
  print STDERR "  -h           = Display a usage statement and exit. \n\n";
  exit 1;
}
