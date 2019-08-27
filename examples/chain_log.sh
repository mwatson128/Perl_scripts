#!/bin/sh

cd /uswsup01/usw/reports/monthly

cp chains.cfg chains.cfg_`/bin/date +\%m\%y`

bin/build_chns.pl

diff chains.cfg chains.cfg_`/bin/date +\%m\%y` > /tmp/tmp.diff

/bin/mailx -s "Please look at chains.cfg" mike.watson@pegs.com < /tmp/tmp.diff

