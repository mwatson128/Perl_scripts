#!/bin/bash

. /`uname -n`/informix/etc/`uname -n`_1.inf_setup
PATH=.:/bin:$INFORMIXDIR/bin:/uswsup01/usw/offln/bin:/usr/sbin:/usr/local/bin:/uswsup01/usw/reports/monthly/bin:$PATH

#INFORMIXDIR=/informix
#INFORMIXSERVER=uswsup01_1; export INFORMIXSERVER
#INFORMIXDIR=/informix-$INFORMIXSERVER; export INFORMIXDIR
#PATH=.:/bin:$INFORMIXDIR/bin:/uswsup01/usw/offln/bin:/usr/sbin:/usr/local/bin:/uswsup01/usw/reports/monthly/bin
#ONCONFIG=onconfig.uswsup01_1; export ONCONFIG
#INFORMIXSERVER=usw_dss
#DBCENTURY=C
#LD_LIBRARY_PATH=$INFORMIXDIR/lib:$INFORMIXDIR/lib/esql
#export INFORMIXDIR ONCONFIG INFORMIXSERVER DBCENTURY LD_LIBRARY_PATH PATH


month_end.pl

