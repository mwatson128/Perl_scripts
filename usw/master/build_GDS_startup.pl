#!/bin/perl
# Accepts one argument, that is the configuration file to read in.

########################
##  Data structures setup.
########################

# If we get an ARGV and the file exist, use it.
if ($ARGV[0] && (-e $ARGV[0])) {
  $DATAFILE = "<" . $ARGV[0];
  print "Using $ARGV[0]\n";
}
else {
  print "Using gds_startup.cfg\n";
  $DATAFILE = "<gds_startup.cfg";
}

########################
##  Forward declarations
########################

sub read_config;
sub print_options;
sub generate_startups;

########################
# MAIN
########################

# Read in the gds_startup.cfg
open DATAFILE or die "No GDS config file found: $DATAFILE\n";
read_config();
close DATAFILE;
#print_options();
generate_startups();
exit(0);

########################
# read_config()
########################
sub read_config {

  $ln_cnt = 1000;
  while (<DATAFILE>) {
    chomp;
    $ln_cnt++;

    # Compile list of GDS's
    next if /^$|^#/;
    if ($_ =~ /{/) {
      chomp $_;
      chop $_;
      chop $_;
      $config_type = $_;
    }
    elsif ($_ =~ / = /) {
      ($key, $value) = split / = /, $_;
      $key =~ s{\A\s*|\s*\z}{}gmsx; # remove leading and trailing whitespace
      $value =~ s{\A\s*|\s*\z}{}gmsx; # remove leading and trailing whitespace

      # We can fill in the data directory without waiting for all data be be
      # parsed, as long as CONN_GROUP is the first element in the group.
      if ("CONNGROUP" eq $key) {
        $conn_group{$value} = $value;
        $conncur = $value;
	next; 
      }
      if ("RELOAD_OPTS" eq $key) {
	@reload_options = split /,/, $value;
	next; 
      }

      if ("GDS_CONNECTION" eq $config_type) {
	if ($key) {
	  if ("GDSINFO" eq $key) {
	    ($gds, $box) = split /:/, $value;
            # Gather a list of boxes this conn resides on
            if ($conncur) {
	      $conn_box_key = $conncur . "_" . $box;
	      $gds_conn_box{$conn_box_key} = $box;
	    }
	    $curkey = $conncur . "_" . $gds;
	    $gds_conn{$curkey} = $box;
	  }
	}
      }
      elsif ("GDS_STARTUP_INFO" eq $config_type) {
	if ($key and $conncur) {
	  $curkey = $conncur . "_" . $key;
	  if ("HDL" eq $key) {
	    $curkey .= "_" . $ln_cnt; 
	    $gds_stup{$curkey} = $value;
	  }
	  else {
	    $gds_stup{$curkey} = $value;
	  }
	}
      }
      elsif ("GDS_OPTIONS" eq $config_type) {
	if ($key and $conncur) {
	  $curkey = $conncur . "_" . $key . "_" . $value;

	  $normal_opt = 1;
	  # seperate out "reload options" from normal ones
	  foreach $opt (@reload_options) {
	    if ($opt eq $key) {
	      $options_val = "-" . $key . " " . $value;
	      $options_file_list{$curkey} = $options_val;
	      $normal_opt = 0;
	      break;
	    }
	  }
	  if ($normal_opt) {
	    # If we've made it here, it's a normal gds_opt value.
	    $gds_opt{$curkey} = $value;
	  } 
	} # End if key and conncur are set
      } # End if GDS_OPTIONS is this section
    }
  }
}


########################
# print_options()
########################
sub print_options {

  foreach $grp (sort keys %conn_group) {
    print "GDS: $grp \n"; 
    foreach $key (sort keys %gds_opt) {
      ($gds, $type, $rkey, $arg) = split /_/, $key;
      $opt_key = $gds . "_" . $type; 
      #print " GDS - $gds, TYPE - $type, RKEY - $rkey, ARG - $arg\n"; 
      if ($grp eq $opt_key) {
        print "  $rkey = $arg\n"; 
      }
    }
  }
}

########################
# generate_startups();
########################
sub generate_startups {

  # Due to the one to many relationship of the options files, there is one 
  # per GDS and that is copied to all of the boxes that GDS is run on, we
  # will run through the list twice.  Once to make the options file and 
  # once more to copy it to the box.  That's why we're looping through 
  # %gds_conn_box twice here.

  # One Loop, create options file, one per GDS
  foreach $gds_plus (sort keys %gds_conn_box) {
    $gds_box = $gds_conn_box{$gds_plus};
    (@gds_parts) = split /_/, $gds_plus;
    $gds_whole = $gds_parts[0] . "_" . $gds_parts[1]; 
    $gds = $gds_parts[0];

    # define and open the sip3 file
    $options_file = "options_" . $gds_whole;
    $OFP = ">${options_file}";
    open OFP or die "Can't open startup file for writing \n";

    # Write out the header lines (HDL)
    printf OFP "# Options loading file generated by build_GDS_startup.pl.\n";
    printf OFP "# Please, do not hand edit!\n";

    # Now go through and add the args.
    foreach $opts (sort keys %options_file_list) {
      (@opt_parts) = split /_/, $opts;
      $opt_gds = $opt_parts[0];
      if ($gds eq $opt_gds) {
        $option_tolist = $options_file_list{$opts};
        printf OFP "$option_tolist \n";
      }
    }
    close OFP;
  }

  # Two Loop, now copy the file out to the CE's dir
  foreach $gds_plus (sort keys %gds_conn_box) {
    $gds_box = $gds_conn_box{$gds_plus};
    (@gds_parts) = split /_/, $gds_plus;
    $options_file = "options_" . $gds_parts[0] . "_" . $gds_parts[1];

    $cvs_dir = "../" . $gds_box . "/config";
    qx(cp $options_file $cvs_dir);
  }

  foreach $conn (sort keys %gds_conn) {
    ($conn_gds, $conn_type, $cur_gds, $cur_type) = split /_/, $conn;

    # KLUDGE for third character capitols, the third letter is either a 
    # number or a capitol letter, only in the sip3 file names.
    ($g_1, $g_2, $g_3) = split //,$cur_gds;
    $gw_1 = lc $g_1 . $g_2;
    #print "first: $g_1,  second: $g_2, third: $g_3 \n";
    $gds_sn = $gw_1 . $g_3 . "_" . lc $cur_type;

    # define and open the sip3 file
    $gds_sfile = "sip3.${gds_sn}";
    $mv_target = "../${gds_conn{$conn}}/config";
    $OFP = ">${gds_sfile}";
    open OFP or die "Can't open startup file for writing \n";

    # Write out the header lines (HDL)
    foreach $ln (sort keys %gds_stup) {
      ($ln_gds, $ln_type, $ln_key, @lval) = split /_/, $ln;
      if ($conn_gds eq $ln_gds) {
        if ("GDSBINARY" eq $ln_key) {
	  $bin_name = $gds_stup{$ln};
	}
	elsif ("HDL" eq $ln_key) {
	  $gds_stup{$ln} =~ tr/@/\n/;
	  printf OFP "$gds_stup{$ln}";
	}
      }
    }
    printf OFP "\n";
    
    # Make up the options file for this gateway.
    $gw_opt = "-l config/options_" . $g_1 . $g_2 . "_" . $cur_type . " ";

    # the krun command
    $krun = "krun -r -i $bin_name";

    # Now write out the krun line, looks like:
    # krun -r -i tweb3a -q GW2-A2
    printf OFP "\n${krun} -q ${cur_gds}-${cur_type}2 $gw_opt\\\n";

    # Now go through and add the args.
    $num_args = 3;
    foreach $op (sort keys %gds_opt) {
      ($op_gds, $op_type, $op_rkey, $op_arg) = split /_/, $op;
      if ($conn_gds eq $op_gds) {
	$num_args++;
	if (1000 <= $num_args) { 
	  die "ARGUMENTS EXCEDDED 1000 Theres a BIG PROBLEM!\n";
	}
	 
	$cur_len = length $cur_out;
	$arg_to_add = " -" . $op_rkey . " " . $op_arg . " ";
	$arg_len = length $arg_to_add;
	if (66 <= $cur_len + $arg_len) {
          printf OFP "$cur_out \\\n"; 
	  $cur_out = $arg_to_add;
	}
	else {
	  $cur_out .= $arg_to_add;
	}
      }
    }
    $args_key = $conn_gds . "_" . $conn_type;
    $max_args{$args_key} = $num_args;
    
    # Clear the last arguments from $cur_out
    printf OFP "$cur_out \n"; 
    $cur_out = "";

    #  Now put in the kqwait line
    printf OFP "\nkqwait ${cur_gds}-${cur_type}2 \n\n";
    close OFP;

    # Make sure it's execute bit is set.
    qx(chmod 755 $gds_sfile);

    # Move gds_sfile to mv_target
    qx(mv $gds_sfile $mv_target);
  }

  # print max number of args for each GDS.
  foreach $args_key (sort keys %max_args) {
    print "Max args for GDS $args_key is $max_args{$args_key} \n";
  }
}


