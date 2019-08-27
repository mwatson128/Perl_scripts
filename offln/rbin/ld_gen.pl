#!/bin/perl

# generate the config files used by dbload
open (HT, ">$ht_config");
print HT "FILE '$archive/ht$mn$dy$yr.txt' DELIMITER '|' 50;\n";
print HT "INSERT INTO hotel_trip_arch;\n";
close(HT);
open (HTX, ">$htx_config");
print HTX "FILE '$archive/htx$mn$dy$yr.txt' DELIMITER '|' 8;\n";
print HTX "INSERT INTO hotel_trip_extras_arch;\n";
close(HTX);
## Then, set up the dbload command line
$options  = " -d $ENV{'ARCH_DBASE'}";      # specify the database
$options .= " -n 5000";                    # specify the commit interval
$options .= " -l $logbase/dbload.errors";  # specify the error log file
$options .= " -r";                         # load without locking table

## Then, run dbload to get the data into the archive table
system("date >> $logfile");
system("date >> $errfile");
print "dbload -c $ht_config $options >> $logfile 2>> $errfile\n";
system("dbload -c $ht_config $options >> $logfile 2>> $errfile");
system("date >> $logfile");
system("date >> $errfile");
print "dbload -c $htx_config $options >> $logfile 2>> $errfile\n";
#system("dbload -c $htx_config $options >> $logfile 2>> $errfile");

