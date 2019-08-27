#!/bin/perl
# Accepts one argument, that is the configuration file to read in.

########################
##  Data structures setup.
########################

$GET_FROM_CVS = 1;
# If we get an ARGV and the file exist, use it.
if ($ARGV[0]) {
  if (("PROD" eq $ARGV[0]) || ("prod" eq $ARGV[0])) {
    $sys = "prod";
    print "getting options from PROD CVS \n";
    $GET_FROM_CVS = 1;
  }
  elsif (("UAT" eq $ARGV[0]) || ("uat" eq $ARGV[0])) {
    $sys = "uat";
    print "getting options from UAT CVS \n";
    $GET_FROM_CVS = 1;
  }
  elsif ($ARGV[0] && (-e $ARGV[0])) {
    $DATAFILE = "<" . $ARGV[0];
    print "getting options from $ARGV[0]\n";
    $GET_FROM_CVS = 0;
  }
  else {
    $sys = "prod";
    print "getting options from PROD CVS \n";
    $GET_FROM_CVS = 1;
  }
}

@gdslist = ("GW", "HD");
$cvshome = "${ENV{CVSDIR}}/usw/";

########################
##  Forward declarations
########################

sub read_config;
sub print_options;


########################
# MAIN
########################

# Read in the gds_startup.cfg
read_config();
print_options();
exit(0);

########################
# read_config()
########################
sub read_config {

  if ($GET_FROM_CVS) {
    
    foreach $gds (@gdslist) {
      #print "\nProcessing $gds \n";
      chomp $gds;
      $lc_gds = lc $gds;
      #  Get the startups from sys, put them into an array
      print "Getting list from ${cvshome}${sys}/*${sys}*/config\n";
      @sfiles = `ls -1 ${cvshome}${sys}/*${sys}*/config/sip3.${lc_gds}*`;
      foreach $sfile (@sfiles) {
        chomp $sfile;
	#print "MIKEW1: $sfile\n";
	# gather gds key for options.
	($other, $gds_type) = split /_/, $sfile;
	$connkey = uc $gds . "_" . $gds_type;
	$conn_group{$connkey} = $connkey;
	open IFP, $sfile;
	@cur_file = <IFP>;
	close IFP;

        # Figure out where the krun line is.
        for ($itr = 0; $cur_file[$itr]; $itr++) { 
	  next if ($cur_file[$itr] =~ /^#|^$/);
	  if ($cur_file[$itr] =~ /krun/) {
	    $k_line = $itr;
	    break;
	  }
	}
	#print "K line is: $k_line\n";
	  
        for ($itr = 0; $cur_file[$itr]; $itr++) { 
	  chomp $cur_file[$itr];
	  #print "Examining $itr: $cur_file[$itr]\n";

          # Skip comments and such.
	  next if ($itr < $k_line);
	  next if ($cur_file[$itr] =~ /^#|^$/);
	  next if ($cur_file[$itr] =~ /kqwait/);

	  if ($itr == $k_line) {
	    #print " In krun line \n";
	    # seperate by argument
	    @args = split / -/,$cur_file[$itr];
	    foreach $arg (@args) {
	      # seperate argument into letter and rest.
	      ($let, $list) = split / /, $arg;
	      next if ($let eq 'krun');
	      next if ($let eq 'i');
	      next if ($let eq 'c');
	      next if ($let eq 'q');
	      $hkey = $connkey . "_" . $let . "_" . $list;
	      $gds_opt{$hkey} = $hkey;
	    }
	  }
          #  ncdctl lines are different as well.
	  elsif ($cur_file[$itr] =~ /ncdctl/) {
	    #print " In ncdctl line \n";
	    # seperate by argument
	    @args = split / -/,$cur_file[$itr];
	    foreach $arg (@args) {
	      # seperate argument into letter and rest.
	      ($let, $list) = split / /, $arg;
	      next if ($let eq 'ncdctl');
	      next if ($let eq 'r');
	      next if ($let eq 'd');
	      $hkey = $connkey . "_" . $let . "_" . $list;
	      $gds_opt{$hkey} = $hkey;
	    }
	  }
	  else {
	    # seperate by argument
	    #print "MIKEW3: $cur_file[$itr]\n";
	    #print " In else line \n";
	    @args = split / -/,$cur_file[$itr];
	    foreach $arg (@args) {
	      # seperate argument into letter and rest.
	      ($let, $list) = split / /, $arg;
	      $let =~ s/-//;
	      $hkey = $connkey . "_" . $let . "_" . $list;
	      $gds_opt{$hkey} = $hkey;
	    }
	  }
	}
      }
    }
  }
  else {

    open DATAFILE or die "No GDS config file found: $DATAFILE\n";
    $ln_cnt = 0;
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

	if ("GDS_CONNECTION" eq $config_type) {
	  if ($key) {
	    if ("GDSINFO" eq $key) {
	      ($gds, $box) = split /:/, $value;
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
	    $gds_opt{$curkey} = $value;
	  }
	}
      } # End elsif = 
    }  # End WHILE DATAFILE
    close DATAFILE;
  }
}

########################
# print_options()
########################
sub print_options {

  foreach $grp (sort keys %conn_group) {
    print "\n--------------\n IN GDS: $grp\n\n"; 
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


