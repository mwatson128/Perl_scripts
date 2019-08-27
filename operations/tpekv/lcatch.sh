#!/bin/sh
# (]$[) lcatch.sh:1.1 | CDATE=03/18/04 18:52:21
#################################
# This is a wrapper for lcatch.  This script is to be run by sudo

ROOTDIR=/prod/perf/kv
PATH=/usr/bin

${ROOTDIR}/lcatch | ${ROOTDIR}/lcatch.pl $ROOTDIR
