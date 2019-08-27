#!/usr/bin/perl 
#
# (]$[) %M%:%I% | CDATE=%G% %U%

###################################
## Forward declare sub routines  ##
###################################
sub cfdb_proc;
sub odd_proc;
use Getopt::Std;

#*SUBTTL Data reference section.
#
# Main HASH data record chart:
# %FR = (
#    property => {
#      odd_brand => "",
#      odd_pid   => "",
#      prop_name => "",
#      prop_ad1  => "",
#      prop_ad2  => "",
#      prop_ad3  => "",
#      prop_ad4  => "",
#      prop_city => "",
#      prop_state => "",
#      prop_zip  => "",
#      prop_cnty => "",
#      prop_phn  => "",
#      prop_bkbl => "",
#      usw_brand => "",
#      usw_pid   => "",
#      1A_brand  => "",
#      1A_pid    => "",
#      UA_brand  => "",
#      UA_pid    => "",
#      AA_brand  => "",
#      AA_pid    => "",
#      1P_brand  => "",
#      1P_pid    => "",
#      prop_updt => "",
#    }
# )

#*SUBTTL pre_proc  
##                                                        
## Read in Config file and setup variables
##
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##
## Locals:
##
##
sub pre_proc {
 
  if ($opt_c) {
    $CIFP = "<$opt_c";
  } else {
    usage();
  }

  open CIFP or die "Can't open config file.\n";

  while (<CIFP>) {
    chomp;
    @cfg_line = split /\|/, $_;
    $CF{ $cfg_line[0] } = $cfg_line[1];
  }

}


#*SUBTTL cfdb_proc  
##                                                        
## Process the CFDB data dump, putting pertinent info in the FR hash.
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    %FR	- Hash used to keep output record
##
## Locals:
##    $mr_key	- Hash key used for FR.
##    @cfdb_tmp	- Temporary array for CFDB info
##    $CIFP	- CFDB dump file pointer
##
sub cfdb_proc {

  $CIFP = "<$pre_fix/cfdb_2.props";
  open CIFP or die "can't open CFDB file!\n";

  while (<CIFP>) {
    chomp;

    @cfdb_tmp = split /\|/, $_;
    $mr_key = $cfdb_tmp[3] . $cfdb_tmp[4];
    
    $FR{ $mr_key }->{usw_brand} = $cfdb_tmp[3];
    $FR{ $mr_key }->{usw_pid} = $cfdb_tmp[4];
    
    if ($cfdb_tmp[0] eq "WB") {
      $FR{ $mr_key }->{odd_brand} = $cfdb_tmp[1];
      $FR{ $mr_key }->{odd_pid} = $cfdb_tmp[2];
    }
    elsif ($cfdb_tmp[0] eq "1A") {
      $FR{ $mr_key }->{AM_brand} = $cfdb_tmp[1];
      $FR{ $mr_key }->{AM_pid} = $cfdb_tmp[2];
    }
    elsif ($cfdb_tmp[0] eq "1P") {
      $FR{ $mr_key }->{WS_brand} = $cfdb_tmp[1];
      $FR{ $mr_key }->{WS_pid} = $cfdb_tmp[2];
    }
    else {
      $br_id = $cfdb_tmp[0] . _brand;
      $pi_id = $cfdb_tmp[0] . _pid;
      $FR{ $mr_key }->{$br_id} = $cfdb_tmp[1];
      $FR{ $mr_key }->{$pi_id} = $cfdb_tmp[2];
    }

  }
  close CIFP;

}

#*SUBTTL odd_proc  
##                                                        
## Process the ODD data dump, putting pertinent info in the FR hash.
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    %FR       - Hash used to keep output record
##
## Locals:
##    $mr_key   - Hash key used for FR.
##    @odd_tmp 	- Temporary array for ODD info
##    $OIFP     - ODD dump file pointer
##
sub odd_proc {

  $OIFP = "<$pre_fix/exp_prop.t";
  open OIFP or die "can't open ODD file!\n";

  while (<OIFP>) {

    chomp;
    @odd_tmp = split /\|/, $_;
    $mr_key = $odd_tmp[13] . $odd_tmp[14];

    $odd_sz = @odd_tmp;
    $FR{ $mr_key }->{odd_org_size} = $odd_sz;
    $FR{ $mr_key }->{odd_brand} = $odd_tmp[0];
    $FR{ $mr_key }->{odd_pid} = $odd_tmp[1];
    $FR{ $mr_key }->{prop_name} = $odd_tmp[2];
    $FR{ $mr_key }->{prop_ad1} = $odd_tmp[3];
    $FR{ $mr_key }->{prop_ad2} = $odd_tmp[4];
    $FR{ $mr_key }->{prop_ad3} = $odd_tmp[5];
    $FR{ $mr_key }->{prop_ad4} = $odd_tmp[6];
    $FR{ $mr_key }->{prop_city} = $odd_tmp[7];
    $FR{ $mr_key }->{prop_state} = $odd_tmp[8];
    $FR{ $mr_key }->{prop_zip} = $odd_tmp[9];
    $FR{ $mr_key }->{prop_cnty} = $odd_tmp[10];
    $FR{ $mr_key }->{prop_phn} = $odd_tmp[11];
    $FR{ $mr_key }->{prop_bkbl} = $odd_tmp[12];
    $FR{ $mr_key }->{usw_brand} = $odd_tmp[13];
    $FR{ $mr_key }->{usw_pid} = $odd_tmp[14];
    $FR{ $mr_key }->{prop_updt} = $odd_tmp[15];
  
  }
  close OIFP;

}

#*SUBTTL usage - diplay usage statement and exit.
##
##
sub usage {

  print "Usage: odd_pid_Xref.pl [options]\n";
  print "  [-c configfile] = configuration file used. Contains name,\n";
  print "     pipe (\|) and directory to deploy file.\n";
  print "  [-d \/directory\/files] = directory of load files.\n";
  print "Odd\/CFDB pid cross reference script.\n";

  exit;
}

#*SUBTTL main - process files and output upload.
##
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    %FR       - Hash used to keep output record
##
## Locals:
##    None
##

getopts('c:d:');

if ($opt_d) {
  $pre_fix = $opt_d;
} else {
  usage();
}

# Process config file:
#pre_proc();

# CFDB INFO:
cfdb_proc();

# ODD INFO:
odd_proc();

# print output file
$TOFP = ">$pre_fix/odd_pid.Xref.t";
open TOFP or die "can't open output file.\n";
foreach $rec ( sort keys %FR ) {

  if ($FR{$rec}{prop_name}) {
    print TOFP "$FR{$rec}{odd_brand}|$FR{$rec}{odd_pid}|$FR{$rec}{prop_name}|",
       "$FR{$rec}{prop_ad1}|$FR{$rec}{prop_ad2}|$FR{$rec}{prop_ad3}|",
       "$FR{$rec}{prop_ad4}|$FR{$rec}{prop_city}|$FR{$rec}{prop_state}|",
       "$FR{$rec}{prop_zip}|$FR{$rec}{prop_cnty}|$FR{$rec}{prop_phn}|",
       "$FR{$rec}{prop_bkbl}|$FR{$rec}{usw_brand}|$FR{$rec}{usw_pid}|",
       "$FR{$rec}{AM_brand}|$FR{$rec}{AM_pid}|$FR{$rec}{UA_brand}|",
       "$FR{$rec}{UA_pid}|$FR{$rec}{AA_brand}|$FR{$rec}{AA_pid}|",
       "$FR{$rec}{WS_brand}|$FR{$rec}{WS_pid}|$FR{$rec}{prop_updt}|\n";
  }
}

close TOFP;

#foreach $user ( keys %CF ) {
#
  #$out_file = $CF{$user};
  #qx(cp -f /tmp/odd_pid.txt $out_file);
#
#}

exit;
