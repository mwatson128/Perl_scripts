#!/bin/bash

. /`uname -n`/informix/etc/`uname -n`_1.inf_setup
PATH=.:/bin:$INFORMIXDIR/bin:/uswsup01/usw/offln/bin:/usr/sbin:/usr/local/bin:/uswsup01/usw/reports/monthly/bin:$PATH

#INFORMIXDIR=/informix-uswsup01_1
#PATH=.:/bin:$INFORMIXDIR/bin:/usw/offln/bin:/usr/sbin:/usr/local/bin:/uswsup01/usw/reports/monthly/bin:/uswsup01/usw/offln/bin
#ONCONFIG=onconfig.uswsup01_1
#INFORMIXSERVER=uswsup01_1
#DBCENTURY=C
#LD_LIBRARY_PATH=$INFORMIXDIR/lib:$INFORMIXDIR/lib/esql
#export INFORMIXDIR ONCONFIG INFORMIXSERVER DBCENTURY LD_LIBRARY_PATH PATH

cd /uswsup01/usw/reports/monthly
cp /uswsup01/usw/reports/monthly/perfb/gds/ms*.perfb /uswsup01/usw/reports/monthly/perfb/

/uswsup01/usw/reports/monthly/bin/perf_rpt.pl > rpt_ld`pvmon`.txt

echo "load from /uswsup01/usw/reports/monthly/rpt_ld`pvmon`.txt" > rpt_perf_ld.sql
echo "insert into rpt_perf" >> rpt_perf_ld.sql

$INFORMIXDIR/bin/dbaccess usw_perf rpt_perf_ld.sql




