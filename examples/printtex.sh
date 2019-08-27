#!/bin/sh
# (]$[) %M%:%I% | CDATE= %G% %U%

# UltraSwitch monthly report script

. /reports/monthly/bin/environment

set -x
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
cd $TEXDIR/billing

ls $TEXDIR/billing/*/*.bil | lpr -P$PRINTER

# Create .dvi files
LAT=`ls $TEXDIR/billing/*/*.bil`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/billing/*.dvi >/dev/null 2>/dev/null
  rm -f *.dvi
done
ls | lpr -P$PRINTER

rm -f $TEXDIR/billing/*.aux
rm -f $TEXDIR/billing/*.log

##sleep 1200

mailx -s "latex0 printouts" $TEXIES < $BINDIR/latexmessage

echo "The printtex.sh latex printouts finished generating at " `date` >>$LOG
