#!/bin/perl
#
# (]$[) print.pl:1.9 | CDATE= 07:30:32 08/23/02
#
# UltraSwitch monthly billing print script
#

$printer = "s3f001";

#*SUBTTL lpr - print to printer
#
sub lpr 
{
  $printlist = join(" ", @_);
  print("\#lpr -P${printer} $printlist\n");
  system("lpr -P${printer} $printlist");
}

sub cutit_up
{
  # list of files to be printed
  @filelist = @_;

  # number of files to be printed at once
  $number = 20;

  # period of seconds to wait between prints
  $pause = 20;

  $i = 0;
  foreach $file (@filelist) {
    $i++;
    
    push @printlist, $file;
    unless ($i % $number) {
      lpr(@printlist);
      @printlist = ();
      system("sleep $pause");
    }
  }

  if ($i % $number) {
    lpr(@printlist);
    @printlist = ();
  }
}

#*SUBTTL makefilelist - turns 'ls' names into (perl) list of files
#
sub makefilelist
{
  my(@files);
  my(%files);
  my($key);
  my(@keys);
  my($names, @other) = @_;

  # make a list of all files from the listing
  @files = split (" ", `ls $names`);
  #print join("\n", @files), "\n";
  
  # strip off the directory name from each file and make it a key to a hash
  foreach $i (@files) {
    $key = $i;
    $key =~ s#^.*/(.*)#$1#;
    #print "$key :--- $i\n";

    unless($files{$key}) {
      $files{$key} = $i; 
    }
    else {
      $files{"${key}0"} = $i; 
    }
  }

  # sort the files based upon their keys
  @keys = sort(keys(%files));

  # put the fully specified paths into a simple list
  @files = ();
  foreach $i (@keys) {
    push @files, $files{$i};
  }
  #print join("\n", @files), "\n";

  return(@files);
}

#*SUBTTL file_load - greps through the files loading the Worldspan total
# bookings into a csv file.
#
sub file_load
{

  $OFP = "> 1p_numbers.csv";
  open OFP or die "can't open output file!\n";

  foreach $member (sort @_) {

    $cont = qx(cat $member);

    $cont =~ /Global Distribution System: (\w+)/;
    $m_gds = $1;

    if ( "1P" eq $m_gds) {
      $cont =~ /Hotel Reservation System  : (\w+)/;
      print OFP "$1,";
      #$m.hrs = $1;
      $cont =~ /Total Net Bookings\s+(-*\d+)/;
      print OFP "$1\n";
      #$m.totals = $1;
    }
  }
  close OFP;
}

#*SUBTTL main - main
#
{
  # change directory to the month-end billing directory
  chdir "/usw/reports/monthly/billing/";

  # print copy of HRS billing for accounting
  # (Roz sends a copy of these to the HRS to back up the invoice)
  # (a second copy is made by Toni so she can begin entering the numbers early)
  #@hrsfiles = makefilelist("*.bil hrs/*.bil hrs2/gt*.bil hrs2/xl*.bil hrs2/wr*.bil hrs2*/es*.bil hrs2*/hg*.bil hrs2*/hx*.bil hrs2gds/aaes*.bil  hrs2gds/uaes*.bil hrs2gds/1aes*.bil hrs2gds/wbes*.bil hrs2gds/aahx*.bil hrs2gds/uahx*.bil hrs2gds/1ahx*.bil hrs2gds/wbhx*.bil hrs2gds/aahg*.bil hrs2gds/uahg*.bil hrs2gds/1ahg*.bil hrs2gds/wbhg*.bil hrs2gds/aarl*.bil hrs2gds/uarl*.bil hrs2gds/1arl*.bil hrs2gds/wbrl*.bil hrs2gds/aadt*.bil hrs2gds/uadt*.bil hrs2gds/1adt*.bil hrs2gds/wbdt*.bil");
  @hrsfiles = makefilelist("all0103.bil");
  cutit_up(@hrsfiles);

  # get a list of billing files for the GDSs 
  # (Roz enters these into the spreadsheet)
  # (only 3A and TW are sent to customers; the rest are internal)
  #@gdsfiles = makefilelist("gds/*.bil hrsgds/*.bil hrs2gds/1p*.bil ");
  #cutit_up(@gdsfiles);
  #file_load(@gdsfiles);

}

# the problem:  I've taken off the directory name to sort the list, but I 
# need it again to print the files out.
