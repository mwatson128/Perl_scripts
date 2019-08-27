#!/bin/ksh 
# This script runs sfpull.pl loading the environment and then passing it 
# all args.
#
# Designed for cron job use.
#

# Source environment to get directory information
. /`uname -n`/prod/home/.environment

TZ=GMT0; export TZ

exec $PRODDIR/home/bin/sfpull.pl $1 $2 $3 $4

