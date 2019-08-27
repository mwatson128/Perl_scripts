# !/bin/sh
# (]$[) %M%:%I% | CDATE= %G% %U%
# UltraSwitch monthly report script

. /usw/reports/monthly/bin/environment

set -x
cd $TEXDIR/billing

echo "start time for latex0.sh reports is " `date` >>$LOG

#billing -m -o latex -h ST > $TEXDIR/billing/hrs2/st${DS}.bil  2>>$LOG
#billing -m -o latex -h ST -a "1P" > $TEXDIR/billing/hrs2gds/wsst${DS}.bil  2>>$LOG
#billing -m -o latex -h ST -a AA > $TEXDIR/billing/hrs2gds/aast${DS}.bil  2>>$LOG
#billing -m -o latex -h ST -a "UA|1V|1C|1G" > $TEXDIR/billing/hrs2gds/uast${DS}.bil  2>>$LOG
#billing -m -o latex -h ST -a 1A > $TEXDIR/billing/hrs2gds/1ast${DS}.bil  2>>$LOG
#billing -m -o latex -h ST -a "WB|MS"> $TEXDIR/billing/hrs2gds/wbst${DS}.bil  2>>$LOG

#billing -m -o latex -h "LM|YO|HV|BB|DS|GD|HR|SJ|SB|ST|JV|FT|FH|FM|CJ|CE|BU|AH" > $TEXDIR/billing/hrs/lm${DS}.bil  2>>$LOG
#billing -m -o latex -h "LM|YO|HV|BB|DS|GD|HR|SJ|SB|ST|JV|FT|FH|FM|CJ|CE|BU|AH" -a "1P" > $TEXDIR/billing/hrsgds/wslm${DS}.bil  2>>$LOG
billing -m -o latex -h "LM|YO|HV|BB|DS|GD|HR|SJ|SB|ST|JV|FT|FH|FM|CJ|CE|BU|AH" -a AA > $TEXDIR/billing/hrsgds/aalm${DS}.bil  2>>$LOG
#billing -m -o latex -h "LM|YO|HV|BB|DS|GD|HR|SJ|SB|ST|JV|FT|FH|FM|CJ|CE|BU|AH" -a "UA|1V|1C|1G" > $TEXDIR/billing/hrsgds/ualm${DS}.bil  2>>$LOG
#billing -m -o latex -h "LM|YO|HV|BB|DS|GD|HR|SJ|SB|ST|JV|FT|FH|FM|CJ|CE|BU|AH" -a 1A > $TEXDIR/billing/hrsgds/1alm${DS}.bil  2>>$LOG
#billing -m -o latex -h "LM|YO|HV|BB|DS|GD|HR|SJ|SB|ST|JV|FT|FH|FM|CJ|CE|BU|AH" -a "WB|MS"> $TEXDIR/billing/hrsgds/wblm${DS}.bil  2>>$LOG

#billing -m -o latex -h "UZ|LE|ER|JU|EL|JH" > $TEXDIR/billing/hrs/uz${DS}.bil 2>>$LOG
#billing -m -o latex -h "UZ" > $TEXDIR/billing/hrs2/uz${DS}.bil 2>>$LOG
#billing -m -o latex -h "LE" > $TEXDIR/billing/hrs2/le${DS}.bil 2>>$LOG
#billing -m -o latex -h "ER" > $TEXDIR/billing/hrs2/er${DS}.bil 2>>$LOG
#billing -m -o latex -h "JU" > $TEXDIR/billing/hrs2/ju${DS}.bil 2>>$LOG
#billing -m -o latex -h "EL" > $TEXDIR/billing/hrs2/el${DS}.bil 2>>$LOG
#billing -m -o latex -h "JH" > $TEXDIR/billing/hrs2/jh${DS}.bil 2>>$LOG

