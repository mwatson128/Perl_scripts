#! /bin/sh
# (]$[) month6.sh:1.24 | CDATE=11/29/06 14:44:19
# perform any monthly maintainance 
# (ie. This script is not for running reports.)
#
# The source for this script is in usw_test:/usw/src/scripts/offln
#
# arg1 = "" OR mm/dd/yy

ZONE=`uname -n`

# Set paths
PATH=.:/usr/bin:/usr/ccs/bin:/$ZONE/usw/offln/bin:/usr/ucb

################################################################
# delete X-month old directory 
#
expire_old_month_dir()
{

  DATE=$1
  SOURCEDIR=$2
  MOS_TO_EXPIRE=$3

  OLDDIR=`find_expired_dir $DATE $MOS_TO_EXPIRE `

  cd ${SOURCEDIR}

  if [ ! -d ${SOURCEDIR}/${OLDDIR} ]
  then
    echo "Directory ${SOURCEDIR}/${OLDDIR} has already been deleted!" >>$LOG
  else
    rm -rf ${SOURCEDIR}/${OLDDIR}
  fi
}


#######################################################################
# find_expired_dir - calculates the name of directory of the expired 
#                    material.  The name will be in "yymm" (last two
#                    digits of year and two digit month) format.
#
# $1 	- date of report as it is run.  date must be in mm/dd/yy format
# $2	- number of months old data is kept around. (can be > 12 mos.)
#
find_expired_dir()
{
  #turn off command echoing for this function
  set +x

  #validate parameters
  if [ -n "$1" ]
  then
	DATE=`xdate $1 1`
	DATEMONTH=`echo $DATE | cut -c1,2`
	DATEYEAR=`echo $DATE | cut -c5,6`
  else
	echo "$MONTHX find_expired_dir(): parameter missing." >>$LOG
	exit 1
  fi
  if [ -n "$2" ]
  then
	MOS_TO_EXPIRE=$2
  else
	echo "$MONTHX find_expired_dir(): parameter missing." >>$LOG
	exit 1
  fi

  #determine how many years need to be knocked off the year
  #(for expire periods greater than one year)
  EXP_YEARS=`echo "${MOS_TO_EXPIRE} / 12 " | bc`
  if [ $EXP_YEARS -gt 0 ]
  then
    DATEYEAR=`echo "${DATEYEAR} - ${EXP_YEARS} " | bc`
  fi

  #determine the magic expire month 
  #use the modulo operator to get remainder
  #(has to do with dec=12, jan=1 wraparound)
  #(for expire periods greater than one year)
  #
  EXP_MOD_MO=`echo "${MOS_TO_EXPIRE} % 12 " | bc`

  #if the current month won't cause 
  #the expired month to be in last year,
  #subtract the modulo-month from this month;
  #otherwise, do some math, and decrement the year
  #
  if [ $DATEMONTH -gt $EXP_MOD_MO ]
  then
    OLDMONTH=`echo "${DATEMONTH} $EXP_MOD_MO" |\
	      awk '{printf "%02d", $1 - $2}' `
  else
    OLDMONTH=`echo "12 ${EXP_MOD_MO} ${DATEMONTH}" |\
	      awk '{printf "%02d", $1 - $2 + $3}' `
    if [ "$DATEYEAR" = "00" ]
    then
      DATEYEAR="99"
    else
      DATEYEAR=`echo "${DATEYEAR}  1 " |\
	      awk '{printf "%02d", $1 - $2}' `
    fi
  fi

  #make the expired directory name and "return" it
  EXPDIR=${DATEYEAR}${OLDMONTH}
  echo $EXPDIR
}

#######################################################################
# seperate_monthly_reports() - creates directory for each month's
#                              worth of reports & moves them in it.
#
# $1	- date report is run at
# $2	- directory monthly reports are in, and to which monthly
#         directory will be added to.
# $3	- the common suffix to the reports (.vbd, .mon, .bil, .perf)
#
seperate_monthly_reports()
{
  #read in parameters
  DATE=`xdate $1 1`
  TARGET_DIR=$2
  SUFFIX=$3

  #calculate previous month and its year
  #if the current month won't cause 
  #the old month to be in last year,
  #subtract the get-old-time from this month;
  #otherwise, do some math, and decrement the year

  set +x
  DATEMONTH=`echo $DATE | cut -c1,2`
  DATEYEAR=`echo $DATE | cut -c5,6`
  EXP_MOD_MO=2

  if [ $DATEMONTH -gt $EXP_MOD_MO ]
  then
    OLDMONTH=`echo "${DATEMONTH} $EXP_MOD_MO" |\
	      awk '{printf "%02d", $1 - $2}' `
  else
    OLDMONTH=`echo "12 ${EXP_MOD_MO} ${DATEMONTH}" |\
	      awk '{printf "%02d", $1 - $2 + $3}' `
    if [ "$DATEYEAR" = "00" ]
    then
      DATEYEAR="99"
    else
      DATEYEAR=`echo "${DATEYEAR}  1 " |\
              awk '{printf "%02d", $1 - $2}' `
    fi
  fi
  set -x

  #make directory name and wildcard for file move
  MON_DIR=${DATEYEAR}${OLDMONTH}
  FILEDATE=${OLDMONTH}${DATEYEAR}

  if [ -d ${TARGET_DIR}/${MON_DIR} ]
  then
        echo "Monthly directory ${TARGET_DIR}/${MON_DIR} already exists!"
  else
        cd ${TARGET_DIR}
	mkdir ${MON_DIR}
	mv *${FILEDATE}*.${SUFFIX} ${MON_DIR}
  fi

}


#######################################################################
# seperate_daily_reports() - creates directory for each month's
#                            worth of daily reports & moves them in it.
#
# $1	- date report is run at
# $2	- directory monthly reports are in, and to which monthly
#         directory will be added to.
# $3	- the common suffix to the reports (.vbd, .mon, .bil, .perf)
#
seperate_daily_reports()
{
  #read in parameters
  DATE=`xdate $1 1`
  TARGET_DIR=$2
  SUFFIX=$3

  #calculate previous month and its year
  #if the current month won't cause 
  #the old month to be in last year,
  #subtract the get-old-time from this month;
  #otherwise, do some math, and decrement the year
  
  set +x
  DATEMONTH=`echo $DATE | cut -c1,2`
  DATEYEAR=`echo $DATE | cut -c5,6`
  EXP_MOD_MO=1
  
  if [ $DATEMONTH -gt $EXP_MOD_MO ]
  then
    OLDMONTH=`echo "${DATEMONTH} $EXP_MOD_MO" |\
 	      awk '{printf "%02d", $1 - $2}' `
  else
    OLDMONTH=`echo "12 ${EXP_MOD_MO} ${DATEMONTH}" |\
	      awk '{printf "%02d", $1 - $2 + $3}' `
    if [ "$DATEYEAR" = "00" ]
    then
      DATEYEAR="99"
    else
      DATEYEAR=`echo "${DATEYEAR}  1 " |\
              awk '{printf "%02d", $1 - $2}' `
    fi
  fi
  set -x

  #make directory name and wildcard for file move
  MON_DIR=${DATEYEAR}${OLDMONTH}
  FILEDATE=${OLDMONTH}??${DATEYEAR}
  
  if [ -d ${TARGET_DIR}/${MON_DIR} ]
  then
        echo "Monthly directory ${TARGET_DIR}/${MON_DIR} already exists!"
  else
        cd ${TARGET_DIR}
	mkdir ${MON_DIR}
	mv *${FILEDATE}*.${SUFFIX} ${MON_DIR}
  fi

}


################################################################
# main - execute functions
#
. /$ZONE/usw/reports/monthly/bin/environment

if [ -n "$1" ]
then
	RDATE=`xdate $1 1`
else
	RDATE=`date +%m/%d/%y`
fi

set -x
MONTHX=$0
cd $REPDIR

echo "start time for ${MONTHX} utility is " `date` >>$LOG

seperate_monthly_reports  $RDATE  $BILLDIR          bil
seperate_monthly_reports  $RDATE  $BILLDIR/gds      bil
seperate_monthly_reports  $RDATE  $BILLDIR/hrs      bil
seperate_monthly_reports  $RDATE  $BILLDIR/hrsgds   bil
seperate_monthly_reports  $RDATE  $BILLDIR/hrs2     bil
seperate_monthly_reports  $RDATE  $BILLDIR/hrs2gds  bil
seperate_monthly_reports  $RDATE  $BILLDIR/ms       bil
seperate_monthly_reports  $RDATE  $PERFDIR          perf
seperate_monthly_reports  $RDATE  $PERFDIR/gds      perf
seperate_monthly_reports  $RDATE  $PERF2DIR         perf
seperate_monthly_reports  $RDATE  $PERF2DIR/gds     perf
seperate_monthly_reports  $RDATE  $PERFBDIR         perfb
seperate_monthly_reports  $RDATE  $PERFBDIR/gds     perfb
seperate_monthly_reports  $RDATE  $TRANSDIR         mon
seperate_monthly_reports  $RDATE  $TRANSDIR/gds     mon
seperate_monthly_reports  $RDATE  $TRANSDIR/hrs     mon
seperate_monthly_reports  $RDATE  $TRANSDIR/hrsgds  mon
seperate_monthly_reports  $RDATE  $TRANSDIR/hrs2    mon
seperate_monthly_reports  $RDATE  $TRANSDIR/hrs2gds mon
seperate_monthly_reports  $RDATE  $TRANSDIR/ms      mon
seperate_monthly_reports  $RDATE  $TEXDIR/billing          bil
seperate_monthly_reports  $RDATE  $TEXDIR/billing/gds      bil
seperate_monthly_reports  $RDATE  $TEXDIR/billing/hrs      bil
seperate_monthly_reports  $RDATE  $TEXDIR/billing/hrsgds   bil
seperate_monthly_reports  $RDATE  $TEXDIR/billing/hrs2     bil
seperate_monthly_reports  $RDATE  $TEXDIR/billing/hrs2gds  bil
seperate_monthly_reports  $RDATE  $TEXDIR/trans            mon
seperate_monthly_reports  $RDATE  $TEXDIR/trans/gds        mon
seperate_monthly_reports  $RDATE  $TEXDIR/trans/hrs        mon
seperate_monthly_reports  $RDATE  $TEXDIR/trans/hrsgds     mon
seperate_monthly_reports  $RDATE  $TEXDIR/trans/hrs2       mon
seperate_monthly_reports  $RDATE  $TEXDIR/trans/hrs2gds    mon

seperate_daily_reports  $RDATE  /$ZONE/usw/reports/daily/dumper   dump
seperate_daily_reports  $RDATE  /$ZONE/usw/reports/daily/opsrpt   opsrpt
seperate_daily_reports  $RDATE  /$ZONE/usw/reports/daily/vol      vol.Z
seperate_daily_reports  $RDATE  /$ZONE/usw/reports/daily/sum      sum.Z
seperate_daily_reports  $RDATE  /$ZONE/usw/reports/daily/per      sum.Z
seperate_daily_reports  $RDATE  /$ZONE/usw/reports/daily/logx_err err

expire_old_month_dir    $RDATE  /$ZONE/usw/reports/daily/sum	2
expire_old_month_dir    $RDATE  /$ZONE/usw/reports/daily/vol 	2
expire_old_month_dir    $RDATE  /$ZONE/usw/reports/daily/logx_err 2
expire_old_month_dir    $RDATE  /$ZONE/usw/reports/daily/per 	2

echo "The ${MONTHX} utility finished generating at " `date` >>$LOG

exit 0
