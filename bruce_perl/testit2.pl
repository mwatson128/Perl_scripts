#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;

push (@host,'udprodae02');

$command1="ls -lrt scripts/*";

foreach $server (@host) {

  print '='x60,"\n";
  print "connecting $server\n";
  $exp = Expect->spawn("ssh bfausey\@$server") or die "Cannot spawn ssh: $!\n";
  $exp->expect(30,
               [
                'Password: $',
                sub {
                  my $fh = shift;
                  print $fh "NewDay0725\n";
                  exp_continue;
                }
               ],
#               [
#                eof =>
#                sub {
#                  if ($spawn_ok) {
#                    die "ERROR: premature EOF in login.\n";
#                  } else {
#                    die "ERROR: could not spawn telnet.\n";
#                  }
#                }
#               ],
               [
                timeout =>
                sub {
                  die "No login.\n";
                }
               ],
               '-re', qr'[$>#] $', #' wait for shell prompt, then exit expect
              );
   $exp->send("sudo su - sun1\n");
   $exp->expect(10, '-re', qr'.*[$>#] $' );

   $exp->send("$command1\n");
   $exp->expect(10, '-re', qr'.*[$>#] $' );

   $exp->send("scp bfausey\@adsdevae01:/home/bfausey/testperl.pl /pegs/home/sun1\n");
   $exp->expect(10,
	[ qr/\(yes\/no\)\?\s*$/ => sub { $exp->send("yes\r"); exp_continue; } ],
	[ qr/assword:\s*$/ 	=> sub { $exp->send("NewDay0725\r");  } ],
   );
   $exp->expect(10, '-re', qr'.*[$>#] $' );
   $exp->send("testperl.pl\n");
   $exp->expect(10, '-re', qr'.*[$>#] $' );



   $exp->send("exit\n");
   $exp->expect(10, '-re', qr'.*[$>#] $' );
   $exp->send("exit\n");
}

exit;
