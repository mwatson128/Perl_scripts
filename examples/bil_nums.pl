#!/bin/perl



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

#SUBTTL file_load - greps through the files loading the Worldspan total
# bookings into a csv file.
#
sub file_load
{

  $OFP = "> ../check.bil";
  open OFP or die "can't open output file!\n";

  foreach $member (sort @_) {

    $cont = qx(cat $member);

#    $cont =~ /Global Distribution System: (\w+)/;
#    print OFP "$1,";
    $cont =~ /Hotel Reservation System  : (\w+)/;
    print OFP "$1           ";
    $cont =~ /Total Net Bookings\s+(-*\d+)/;
    print OFP "$1\n";
  }
  close OFP;
}



# Main

# change directory to the month-end billing directory
chdir "/usw/reports/monthly/billing/";

@myfiles = makefilelist("hrs/*.bil");
file_load (@myfiles);

