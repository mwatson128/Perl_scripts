#!/opt/dba/perl5.8.4/bin/perl
use Sybase::DBlib;

$dbs = new Sybase::DBlib $ENV{SYBID}, $ENV{SYBPSWD}, $ENV{DBS} || 
     die "connection to $ENV{DBS} failed $0\n";

print "looking for $ARGV[0]\n";

$dbs->dbcmd("select name,id,type from sysobjects where name like '$ARGV[0]'");
$dbs->dbsqlexec;
if ($dbs->dbresults == SUCCEED) {
  while (@row = $dbs->dbnextrow) {
     if (@row[2] ne 'S ' && @row[2] ne 'U ') {
       $text{@row[0]}=@row[1];
     } else {
       $tables{@row[0]}=@row[1];
     }
  }
}
$dbs->dbcmd("select name,usertype from systypes");
$dbs->dbsqlexec;
if ($dbs->dbresults == SUCCEED) {
  while (@row = $dbs->dbnextrow) {
     $types{@row[1]}=@row[0];
  }
}

$dbs->dbcmd("select name,id from sysobjects where type in ('D','R')");
$dbs->dbsqlexec;
if ($dbs->dbresults == SUCCEED) {
  while (@row = $dbs->dbnextrow) {
     $name{@row[1]}=@row[0];
  }
}

if (exists $text{$ARGV[0]} ) {
  $dbs->dbcmd("select text from syscomments where id = $text{$ARGV[0]}");
    $dbs->dbsqlexec;
    if($dbs->dbresults == 1) {
      while(@row =$dbs->dbnextrow) {
        print @row[0];
      }
    }

} else {

  foreach $tb (sort { uc($a) cmp uc($b) } (keys %tables)) {
    $dbs->dbcmd("select name,usertype,length,prec,scale,cdefault,accessrule from syscolumns where id = $tables{$tb}");
    $dbs->dbsqlexec;
    if($dbs->dbresults == 1) {
      while(@row =$dbs->dbnextrow) {
        if (@row[1] == 2 || @row[1] == 1 || @row[1] == 3 || @row[1] == 4) {
          print uc($tb).",@row[0],$types{@row[1]}(@row[2]) $name{@row[5]} $name{@row[6]}\n";
        } else {
          if(@row[1] == 26 || @row[1] == 10) {
            print uc($tb).",@row[0],$types{@row[1]}(@row[3],@row[4]) $name{@row[5]} $name{@row[6]}\n";
          } else {
            print uc($tb).",@row[0],$types{@row[1]} $name{@row[5]} $name{@row[6]}\n";
          }
        }
      }
    }
  }
}
$dbs->dbclose;
exit;

