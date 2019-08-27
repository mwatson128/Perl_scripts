#!/bin/sh
# (]$[) texprn0.sh:1.1 | CDATE= 04/12/02 09:17:54
# UltraSwitch monthly report script

. /usw/reports/monthly/bin/environment
set -x
PRINTER=hpmkt

cd $TEXDIR/billing

latex $TEXDIR/billing/all${DS}.bil >/dev/null 2>/dev/null
dvips $TEXDIR/billing/all${DS}.dvi >/dev/null 2>/dev/null
rm -r $TEXDIR/billing/*.dvi

rm -r $TEXDIR/billing/*.aux
rm -r $TEXDIR/billing/*.log
