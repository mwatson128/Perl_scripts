#!/bin/sh
# (]$[) hide.sh:1.6 | CDATE= 04/26/99 14:53:49
#
# UltraSwitch MS hiding script
#
SCRIPT=hide.sh
ZONE=`uname -n`

# Import environment
. /$ZONE/usw/reports/monthly/bin/environment

# This function searches for any WB|MS strings in all of the billing and trans
# WB reports as well as the latex billing and trans WB reports.
looky()
{
  egrep -l 'WB|MS' /$ZONE/usw/reports/monthly/*/*/wb*.*
  egrep -l 'WB|MS' /$ZONE/usw/reports/monthly/texreports/*/*/wb*.*
}

# This function takes the results of the searches, looks through the file for
# all instances of WB|MS, and replaces them with just the WB.
bghide()
{
  flag=0
  read file
  while [ 0 -eq $? ]
  do
    flag=1
    echo "hiding $file...shhh!!!"
    sed "s/WB|MS/WB/g" $file > $file.new
    mv $file.new $file
    read file
  done
  if [ $flag -eq 1 ]
  then 
    echo "I hid some files for you.  -Hide" | mail $HIDEMAIL
  else 
    echo "I could not find any files.  What's up?  -Hide" | mail $HIDEMAIL
  fi
    echo "done."
}

# The main program, it calls looky and pipes the output into bghide.
looky | bghide
