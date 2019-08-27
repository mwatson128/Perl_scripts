#!/bin/sh
# (]$[) texprn1.sh:1.1 | CDATE= 04/12/02 09:18:02
# UltraSwitch monthly report script

. /usw/reports/monthly/bin/environment

PRINTER=hpmkt
export PRINTER

set -x
cd $TEXDIR/trans

latex $TEXDIR/trans/all${DS}.mon >/dev/null 2>/dev/null
dvips $TEXDIR/trans/all${DS}.dvi >/dev/null 2>/dev/null
rm -r $TEXDIR/trans/*.dvi

# Create .dvi files
LAT=`ls $TEXDIR/trans/gds/*.mon`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/trans/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

LAT=`ls $TEXDIR/trans/hrs/*.mon`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/trans/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

LAT=`ls $TEXDIR/trans/hrs2/*.mon`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/trans/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

LAT=`ls $TEXDIR/trans/hrsgds/*.mon`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/trans/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

LAT=`ls $TEXDIR/trans/hrs2gds/*.mon`
for FILE in $LAT
do
  latex $FILE >/dev/null 2>/dev/null
  dvips $TEXDIR/trans/*.dvi >/dev/null 2>/dev/null
  rm -r *.dvi
done

rm -r $TEXDIR/trans/*.aux
rm -r $TEXDIR/trans/*.log
