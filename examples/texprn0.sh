#!/bin/sh
# (]$[) texprn0.sh:1.1 | CDATE= 04/12/02 09:17:54
# UltraSwitch monthly report script

. /usw/reports/monthly/bin/environment
set -x

cd $TEXDIR/billing

latex $TEXDIR/billing/all${DS}.bil >/dev/null 2>/dev/null
dvips $TEXDIR/billing/all${DS}.dvi >/dev/null 2>/dev/null
rm -r $TEXDIR/billing/*.dvi

# Create .dvi files
LAT=`ls $TEXDIR/billing/gds/*.bil`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/billing/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

LAT=`ls $TEXDIR/billing/hrs/*.bil`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/billing/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

LAT=`ls $TEXDIR/billing/hrs2/*.bil`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/billing/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

LAT=`ls $TEXDIR/billing/hrsgds/*.bil`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/billing/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

LAT=`ls $TEXDIR/billing/hrs2gds/*.bil`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/billing/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

rm -r $TEXDIR/billing/*.aux
rm -r $TEXDIR/billing/*.log
