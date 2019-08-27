#!/opt/dba/perl5.8.4/bin/perl
use Sybase::DBlib;

$dbs = new Sybase::DBlib $ENV{SYBID}, $ENV{SYBPSWD}, $ENV{DBS} || 
     die "connection to $ENV{DBS} failed $0\n";

$dbs->dbcmd("exec $ARGV[0] '$ARGV[1]'");
$dbs->dbsqlexec;
if ($dbs->dbresults == SUCCEED) {
  while (@row = $dbs->dbnextrow) {
    foreach $col (@row) {
      print "$col ";
    }
    print "\n";
  }
}
$dbs->dbclose;
exit;

