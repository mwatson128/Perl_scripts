#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;

push (@host,'udprodae01');
push (@host,'udprodae02');
push (@host,'udprodae03');
push (@host,'udprodae04');
push (@host,'udprodae05');
push (@host,'udprodae06');
push (@host,'udprodae07');
push (@host,'udprodae09');
push (@host,'udprodae11');
push (@host,'udprodae12');
push (@host,'udprodae13');
push (@host,'udprodae14');
#push (@host,'adsuatstage01');
#push (@host,'adsuatprodae01');
#push (@host,'adsuatprodae02');
#push (@host,'adsqagrid01');
#push (@host,'adsgriduatstage01');
#push (@host,'adsgriduatprod01');
#push (@host,'benchae01');
#push (@host,'benchae02');
#push (@host,'benchae04');
#push (@host,'bench13');
#push (@host,'adsgridprod01');
#push (@host,'adsgridprod02');
#push (@host,'adsgridprod03');
#push (@host,'adsgridprod04-new');
#push (@host,'adsgridprod05');
#push (@host,'adsgridprod06');
#push (@host,'adsprodae01');
#push (@host,'adsprodae02');
#push (@host,'adstoolsae01');
#push (@host,'adstoolsae02');
#push (@host,'uddas02');

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


#   $exp->send("grep BROKERLOGTXT single.pl \n");
#   $exp->expect(10, '-re', qr'.*[$>#] $' );
#   $exp->send("grep MEGW single.pl \n");
#   $exp->expect(10, '-re', qr'.*[$>#] $' );

   $exp->send("exit\n");
   $exp->expect(10, '-re', qr'.*[$>#] $' );
   $exp->send("exit\n");
}

exit;
