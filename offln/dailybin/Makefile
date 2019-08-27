# Make report scripts executable >/dev/null 2>/dev/null
# (]$[) Makefile:1.2 | CDATE=06/04/97 21:53:08

SHELL=/bin/sh

QA_SOURCES = qa_offln.pl unit_offln.pl

SOURCES = offln.pl

RESTRICTED = prod_offln.pl rerun_offln.pl

CONFIGS =  lgrpt.pl qcheck.pl lgper.pl

BINDIR = /usw/offln/rbin

latest install:
	@-chmod gu+x $(QA_SOURCES) $(SOURCES) >/dev/null 2>/dev/null
	@-chmod -x  $(RESTRICTED) >/dev/null 2>/dev/null
	@-chmod u+x $(RESTRICTED) >/dev/null 2>/dev/null
	@-chown uswrpt $(SOURCES) $(RESTRICTED) $(CONFIGS) >/dev/null 2>/dev/null
	@-chown qa $(QA_SOURCES) >/dev/null 2>/dev/null

