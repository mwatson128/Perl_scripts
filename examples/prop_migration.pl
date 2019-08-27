#!/usr/local/bin/perl
# (]$[) prop_migration.pl:1.13 | CDATE=05/04/04 15:36:20

############################
#  Environment definitoin  #
############################
$SourceMachine = "twdemo";
$SourceDir = "/ftp/unirez/migration";
$SourceFile = "MU.in";
$SourceUserID = "prod_sup";
$DestDir = "/usr2/usw/prod";
$DestFile = "MU_MIG_FILE";
$KnetDir = "/usr2/usw/prod/knetbin";
$userid = "usw";
$RootDir = "/usw/src/scripts/prod/tpe/test";
$RootDir = "/prod/migration";
$WorkDir = $RootDir . "/work";
$LogDir = $RootDir . "/logs";
$LogDate = `/bin/date +\%m%d%y`;
chomp $LogDate;
$ArchHour = `/bin/date +\%H`;
chomp $ArchHour;
$ArchTime = $LogDate . $ArchHour;
$LogFile ="mu_mig_log";
$ArchiveDir = $RootDir . "/archive";
@CElist = ( 
            "sunads1", 
            "sunads2", 
            "sunads3", 
            "sunpa", 
            "sunpb", 
            "suntcp3",
            "suntcp4",
            "suntcp5",
            "suntcp6",
            "suntcp7",
            "suntcp8"
          );
%IPlist = ( 
            "1A-A2",  "suntcp6",
            "1A2-A2", "suntcp3",
            "1A-B2",  "sunpb",
            "AA1-A2", "suntcp7",
            "AA2-A2", "suntcp8",
            "AA-B2",  "sunpb",
            "MS-A2",  "suntcp4",
            "MS2-A2", "sunpa",
            "MS3-A2", "sunpa",
            "UA-A2",  "suntcp3",
            "UA-B2",  "sunpb",
            "UZ-A2",  "sunpa",
            "UZ-B2",  "sunpb",
            "WB-A2",  "sunads1",
            "WB2-A2", "sunads2",
            "WB3-A2", "sunads3",
            "WB4-A2", "sunads1",
            "WB5-A2", "sunads2",
            "WS-A2",  "suntcp6",
            "WS2-A2", "suntcp5",
            "WS-B2",  "sunpb"
          );

########################
#  Set up the logging  #
########################
$date = `/bin/date +\%m\/%d\/%y %H:%M`;
chomp $date;
close STDERR;
close STDOUT;
open STDERR, ">> $LogDir/$LogFile.$LogDate" or die "Moot message...\n";
open STDOUT, ">> $LogDir/$LogFile.$LogDate" or die "Moot message...\n";
printf "<--- Starting new check! --- %s --->\n", $date;
$oldfh = select STDOUT; $| = 1;
select STDERR; $| = 1;
select $oldfh;

# Let's go see if a file is out on the source server.
$RCP_Command  =  sprintf "/bin/rcp %s\@%s:%s/%s %s/%s 2>/dev/null",
              $SourceUserID,
              $SourceMachine,
              $SourceDir,
              $SourceFile,
              $WorkDir,
              $DestFile;
if ((0xff00 & system $RCP_Command) > 0) {
  print "No file to process at this time\n<--- FINISHED --->\n\n";
} else {
  print "Found a file!\n";

# Move the file out to the machines.
for $DestMachine (@CElist) {
  $RCP_Command  =  sprintf "/bin/rcp %s/%s %s\@%s:%s/%s 2>/dev/null",
                         $WorkDir,
                         $DestFile,
                         $userid,
                         $DestMachine,
                         $DestDir,
                         $DestFile;
  if ((0xff00 & system $RCP_Command) > 0) {
    print "I was unable to transfer the file to $DestMachine\n";
  }
}

# Send out the ncdctl commands!
for $IP (keys %IPlist) {
  $RSH_Command  =  sprintf "/bin/rsh -n -l %s %s %s/ncdctl -r -d %s -tv", 
                         $userid, 
                         $IPlist{$IP}, 
                         $KnetDir,
                         $IP;
  if ((0xff00 & system $RSH_Command) > 0) {
    print "I was unable to dump the variables for $IP\n";
  }  
  $RSH_Command  =  sprintf "/bin/rsh -n -l %s %s %s/ncdctl -r -d %s -M MU", 
                         $userid, 
                         $IPlist{$IP}, 
                         $KnetDir,
                         $IP;
  if ((0xff00 & system $RSH_Command) > 0) {
    print "I was unable to activate $IP\n";
  }  
  $RSH_Command  =  sprintf "/bin/rsh -n -l %s %s %s/ncdctl -r -d %s -tv", 
                         $userid, 
                         $IPlist{$IP}, 
                         $KnetDir,
                         $IP;
  if ((0xff00 & system $RSH_Command) > 0) {
    print "I was unable to dump the variables for $IP\n";
  }  
}

# Clean up mess and archive files.
$Archive_Command =  sprintf "/bin/mv -f %s/%s %s/%s.%s",
                 $WorkDir, 
                 $DestFile,
                 $ArchiveDir,
                 $DestFile,
                 $ArchTime;
if (0xff00 & system $Archive_Command) {
  print "Problem moving file.\n";
} else { 
  $RM_Command = sprintf "/bin/rsh -n -l %s %s /bin/rm -f %s/%s",
              $SourceUserID,
              $SourceMachine,
              $SourceDir,
              $SourceFile;
  if (0xff00 & system $RM_Command) {
    print "Problem removing file.\n";
  }
}

}

print "<-- FINISHED -->\n\n";

