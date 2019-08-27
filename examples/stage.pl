#!/usr/local/bin/perl
## (]$[) stage.pl:1.5 | CDATE=05/27/04 08:48:23
###########################################################################
##  This script will take the system name as a command line arguement and
##  copy over the files from the system to the staging area.  
###########################################################################

###########################################################################
##  Forward declaration of subroutines
###########################################################################
sub usage;
sub barf;
sub set_defaults;
sub parse_command_line;
sub get_environment;
sub cleanup_staging_area;
sub make_alterations;
sub apply_install;
sub finish;
###########################################################################
##  MAIN
###########################################################################
set_defaults();
parse_command_line();
cleanup_staging_area();
get_environment();
apply_install();
make_alterations();
finish();

###########################################################################
##  Subroutine:  usage
###########################################################################
sub usage {
  print("Please supply system name on command line.\n");
  exit;
}

###########################################################################
##  Subroutine:  barf
###########################################################################
sub barf {
  $DBUG && print(">barf\n");
  print(@_);
  $DBUG && print("<barf\n");
  exit;
}

###########################################################################
##  Subroutine: set_defaults
###########################################################################
sub set_defaults {
  
  # Turn off/on Debugging
  $DBUG = 0;
  
  # Username to rcp files with
  $user = "prod_sup";

  # Staging root
  $staging_root = "/usw/staging";
}

###########################################################################
##  Subroutine:  parse_command_line
###########################################################################
sub parse_command_line {

  $DBUG && print(">parse_command_line\n");
  
  # Grab the first argument and set as the system name
  if ($ARGV[0]) {
    $sys_name = $ARGV[0]; 
  }
  else {
    usage("Please supply system name on command line.\n");
  }

  # Based on the system name set up variables
  if ($sys_name eq "usw_prod") {
    $remote_root = "/prod";
  } 
  else {
    barf("Only setup to be run for usw_prod\n");
  }

  $DBUG && print("<parse_command_line\n");
}
      
###########################################################################
##  Subroutine: get_environment
###########################################################################
sub get_environment {

  $DBUG && print(">get_environment\n");

  # Get the Kivanet binaries
  $GET_KNET = sprintf "rcp -p %s\@%s:%s/knetbin/* %s/knetbin", 
       $user, $sys_name, $remote_root, $staging_root;
  0 == system $GET_KNET or barf("Error Getting Kivanet Binaries\n");
  
  # Get the UltraSwitch binaries
  $GET_USWBIN = sprintf "rcp -p %s\@%s:%s/uswbin/* %s/uswbin", 
       $user, $sys_name, $remote_root, $staging_root;
  0 == system $GET_USWBIN or barf("Error Getting USW binaries\n");
  
  # Get the UltraSwitch configuration
  $GET_CONFIG = sprintf "rcp -p %s\@%s:%s/config/* %s/config", 
       $user, $sys_name, $remote_root, $staging_root;
  system $GET_CONFIG;

  # TPE specific directories to retrieve
  if ($sys_name eq "usw_prod") {
    $GET_CSDESC = sprintf "rcp -p %s\@%s:%s/csdesc/* %s/csdesc",
         $user, $sys_name, $remote_root, $staging_root;
    0 == system $GET_CSDESC or barf("Error Getting TPE directories\n");
  }

  # Copy /prod/inst from usw_prod so that files can be staged
  $GET_INST = sprintf "rcp -p %s\@usw_prod:/prod/inst/s* %s/inst",
         $user, $staging_root;
  0 == system $GET_INST or barf("Error Getting /prod/inst from usw_prod\n");

  # Copy /prod/inst from usw_prod so that files can be staged
  $GET_INST = sprintf "rcp -p %s\@usw_prod:/prod/inst/usw_prod %s/inst",
         $user, $staging_root;
  0 == system $GET_INST or barf("Error Getting /prod/inst from usw_prod\n");

  $DBUG && print(">get_environment\n");
}

###########################################################################
##  Subroutine: cleanup_staging_area
###########################################################################
sub cleanup_staging_area {

  $DBUG && print(">cleanup_staging_area\n");
  
  # Remove all the files in the staging root area
  $RM_ROOT = sprintf "rm -f %s/* 2> /dev/null", $staging_root;
  system $RM_ROOT;
  
  # Remove the staging knetbin directory
  $RM_KNETBIN = sprintf "rm -rf %s/knetbin 2> /dev/null", $staging_root;
  system $RM_KNETBIN;

  # Remove the staging config directory
  $RM_CONFIG = sprintf "rm -rf %s/config 2> /dev/null", $staging_root;
  system $RM_CONFIG;

  # Remove the staging uswbin directory
  $RM_USWBIN = sprintf "rm -rf %s/uswbin 2> /dev/null", $staging_root;
  system $RM_USWBIN;
 
  # Remove install directory
  $RM_INST = sprintf "rm -rf %s/inst 2> /dev/null", $staging_root;
  system $RM_INST;

  # TPE Specific directories to remove
  if ($sys_name eq "usw_prod") {
    $RM_CSDESC = sprintf "rm -rf %s/csdesc", $staging_root;
    system $RM_CSDESC;
  }

  # Recreate knetbin, config, uswbin, and install directories
  $MKDIR_ENV = sprintf "mkdir %s/uswbin %s/config %s/knetbin %s/inst", 
       $staging_root, $staging_root, $staging_root, $staging_root;
  0 == system $MKDIR_ENV 
    or barf("Error creating dirs (uswbin, config, install)\n");

  # TPE Specific directories to create
  if ($sys_name eq "usw_prod") {
    $MKDIR_TPE = sprintf "mkdir %s/csdesc", $staging_root;
    0 == system $MKDIR_TPE or barf("Error creating csdesc dir\n");
  }

  $DBUG && print("<cleanup_staging_area\n");
}

###########################################################################
##  Subroutine:  make_alterations
###########################################################################
sub make_alterations {

  $DBUG && print(">make_alterations\n");
  
  # Do TPE specific alterations
  if ($sys_name eq "usw_prod") {
    
    # Change DBNAME in master.cfg and change STATSUB key
    $CHMOD_MASTER = sprintf "chmod 775 %s/config/master.cfg", $staging_root;
    0 == system $CHMOD_MASTER or barf("Error changing permission on master.cfg\n");
    $CP_MASTER = sprintf "cp %s/config/master.cfg %s/config/master.back",
         $staging_root, $staging_root;
    $SED_MASTER = sprintf "sed 's/usw2onln/testonln/' %s/config/master.back > %s/config/master.cfg", 
         $staging_root, $staging_root;
    0 == system $CP_MASTER or barf("Error changing master.cfg\n");
    0 == system $SED_MASTER or barf("Error changing database\n");
    
    # Change KSF paths in lns.cfg
    $CP_LNS = sprintf "cp %s/config/lns.cfg %s/config/lns.back",
         $staging_root, $staging_root;
    $SED_LNS = sprintf "sed 's/prod/usw\\/staging/' %s/config/lns.back > %s/config/lns.cfg", 
         $staging_root, $staging_root;
    0 == system $CP_LNS or barf("Error changing lns.cfg\n");
    0 == system $SED_LNS or barf("Error changing lns.cfg path\n");

    # Copy the staging STATSUB startup script
    $CP_STATSUB = sprintf "cp -f %s/bin/sstatsub %s/config/sstatsub",
         $staging_root, $staging_root;
    0 == system $CP_STATSUB or barf("Error copying STATSUB\n");

    # Change permissions on STATSUB script
    $CHMOD_STATSUB = sprintf "chmod 775 %s/config/sstatsub", $staging_root;
    0 == system $CHMOD_STATSUB or barf("Error changing permission on STATSUB\n");

    # Copy the staging STATDISP startup script
    $CP_STATD = sprintf "cp -f %s/bin/sstatd %s/config/sstatd",
         $staging_root, $staging_root;
    0 == system $CP_STATD or barf("Error copying STATDISP\n");

    # Change permissions on STATD script
    $CHMOD_STATD = sprintf "chmod 775 %s/config/sstatd", $staging_root;
    0 == system $CHMOD_STATD or barf("Error changing permission on STATD\n");
    
    # Change UKMON paths in sukmon
    $CP_UKMON = sprintf "cp %s/config/sukmon %s/config/sukmon.back",
         $staging_root, $staging_root;
    $SED_UKMON = sprintf "sed 's/prod/usw\\/staging/' %s/config/sukmon.back > %s/config/sukmon", 
         $staging_root, $staging_root;
    0 == system $CP_UKMON or barf("Error coping sukmon\n");
    0 == system $SED_UKMON or barf("Error changing sukmon path\n");
  }

  # Do comm engine specific alterations
  else {
    
    # Copy the staging TCPSES startup script
    $CP_TCPSES = sprintf "cp -f %s/bin/stcpses %s/config/stcpses", 
         $staging_root, $staging_root;
    0 == system $CP_TCPSES or barf("Error copying TCPSES\n");

    # Change permissions on TCPSES script
    $CHMOD_TCPSES = sprintf "chmod 775 %s/config/stcpses", $staging_root;
    0 == system $CHMOD_TCPSES or barf("Error changing permission on TCPSES\n");
  }

  $DBUG && print("<make_alterations\n");
}

###########################################################################
##  Subroutine:  apply_install
###########################################################################
sub apply_install {

  $DBUG && print(">apply_install\n");

  # Build install filename for system
  if ($sys_name eq "usw_prod") {
    $install_file = sprintf "%s/inst/usw_prod", $staging_root;
  } 
  else {
    $install_file = sprintf "%s/inst/%s", $staging_root, $sys_name;
  }

  # Try to open file and if successful read and apply changes
  if (open INSTALL, $install_file) {
  
    # Read install files
    while ($line = <INSTALL>) {
     
      # Split the filename using "/"
      @line = split /\//, $line;

      # Set filename to the last item in the array and remove trainling newline
      $filename = $line[$#line];
      chomp $filename;

      # Set the directory to the next to the last item in the array
      $directory = $line[$#line-1];

      # Build the name of the staging file
      $staging_file = sprintf "%s/%s/%s", $staging_root, $directory, $filename;

      # Check for current file and validate permissions
      if (open CURRENT, $staging_file) {

        # Stat file to get information
        ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, 
             $atime, $mtime, $ctime, $blksize, $blocks) 
             = stat CURRENT;

        # Check file permissions
        if (($mode & 0550) != 0550) {
          $MV_ERR = sprintf "%s does not have the correct permissions.\n", 
			     $staging_file;
          barf($MV_ERR);
        }
        
        # Close the file
        close CURRENT;
       } 
       
       # Can't locate current file
       else {
         $MV_ERR = sprintf "Can't find file %s/%s\n", $directory, $filename;
         barf($MV_ERR);
       }
        

      # Check for the "plus"  file and validate permissions
      if (open PLUS, "$staging_file+") {

        # Stat file to get information
        ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, 
             $atime, $mtime, $ctime, $blksize, $blocks) 
             = stat PLUS; 

        # Check file permissions
        if (($mode & 0550) != 0550) {
          $MV_ERR = sprintf "%s does not have the correct permissions.\n", 
			    "$staging_file+";
          barf($MV_ERR);
        }
        
        # Close the file
        close PLUS;
      }
     
      # Can't locate "plus" file
      else {
        $MV_ERR = sprintf "Can't file file %s/%s\n", $directory, "$filename+";
        barf($MV_ERR);
      }

      # Backup current file
      $MV_CURRENT = sprintf "mv -f %s %s", $staging_file, "$staging_file-";
      0 == system $MV_CURRENT or barf("Error backing up file ($MV_CURRENT)\n");

      # Stage new file
      $MV_PLUS = sprintf "mv -f %s %s", "$staging_file+", $staging_file;
      0 == system $MV_PLUS or barf("Error staging new file ($MV_PLUS)\n");
    }
  }

  $DBUG && print("<apply_install\n");
}
###########################################################################
##  Subroutine:  finish
###########################################################################
sub finish {
  print("\nStaging Completed Successfully\n");
  exit;
}
###########################################################################
