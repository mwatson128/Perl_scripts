#!/bin/perl
#
# (]$[) print.ms:1.1 | CDATE=04/12/02 09:16:10
#
# UltraSwitch monthly billing MS print script
#

$printer = "17_hp8000";

#*SUBTTL lpr - print to printer
#
sub lpr 
{
  $printlist = join(" ", @_);
  #print("lpr -P${printer} $printlist\n");
  system("lpr -P${printer} $printlist");
}

sub splitshit
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

#*SUBTTL main - main
#
{
  # change directory to the month-end billing directory
  chdir "/usw/reports/monthly/";

  # MICROSOFT!!!
  @msfiles = makefilelist("billing/ms/*.bil trans/ms/*.mon ");
  splitshit(@msfiles);

}

