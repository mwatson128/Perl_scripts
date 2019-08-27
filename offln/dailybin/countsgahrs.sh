#! /bin/ksh
# Gets info from LGRPT2 and passes it to SGA counter.
#
# (]$[) countsgahrs.sh:1.2 | CDATE=08/18/00:08:23:55
#

maketemp ()
{

  # If the log file is found, scan through the file with ulgscan, setting
  # some filters and sending the output to a temp file.

  if [ -s ${LGDIR2}/p2r${DATE}${HOUR}.lg ]
  then
    TMPFILE=/tmp/tmp.$$
    echo "-------- ${DATE}${YEAR} ${HOUR}" >> $OUTDIR/sga.${DATE}${YEAR}
    echo "-------- ${DATE}${YEAR} ${HOUR}" >> $OUTDIR/hrs.${DATE}${YEAR}
    DOTHIS="/usw/runtime/bin/ulgscan -c ${LGDIR2}\/p2r${DATE}${HOUR}.lg \"adduswrec LGRPT2|RQTPALSRQ|GDSWB||\" \"adduswrec LGRPT2|RQTRPINRQ|GDSWB||\" \"adduswrec LGRPT2|RQTPALSRQ|GDSMS||\" \"adduswrec LGRPT2|RQTRPINRQ|GDSMS||\" \"find\" \"read -e\" 2>/dev/null | egrep -v 'adduswrec|find|read' > $TMPFILE"
    eval $DOTHIS
    $BASEDIR/countsga.pl < $TMPFILE >> $OUTDIR/sga.${DATE}${YEAR}
    $BASEDIR/counthrs.pl < $TMPFILE >> $OUTDIR/hrs.${DATE}${YEAR}
    rm $TMPFILE

  # If the log file is not found, bail out and complain.

  else
    echo "Requested log (${LGDIR2}/p2r${DATE}${HOUR}.lg)file for hour $HOUR is not found"
  fi

}

#LGDIR2=/prod/logs/lg2
LGDIR2=/loghist/p2r
#LGDIR2=.
#LGDIR2=/qa/logs/lg2
#BASEDIR=.
#BASEDIR=/qa/perf/kv
BASEDIR=/usw/reports/daily/countsga

# Assign parameters entered on the command line 

if [ -z "$1" ]
then 
  DATE=`env TZ=GMT+1 date +%m%d`
  FILE=`env TZ=GMT+1 date +%H`
else 
  DATE=$1
  FILE=$2
fi

YEAR=`env TZ=GMT+1 date +%y`
OUTDIR=$BASEDIR/`env TZ=GMT+1 date +%y%m`
 
if [ ! -d "$OUTDIR" ]
then
  mkdir $OUTDIR
fi

for HOUR in $FILE
do
  maketemp
done
