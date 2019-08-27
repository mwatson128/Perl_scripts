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
#push (@host,'udprodae10');
#push (@host,'udprodae11');
#push (@host,'udprodae12');
#push (@host,'udprodae13');
#push (@host,'udprodae14');
#push (@host,'udprodae15');
#push (@host,'udprodae16');
#push (@host,'udprodae17');
#push (@host,'udprodae18');
#push (@host,'udprodae19');
#push (@host,'udprodae20');

foreach $server (@host) {

  print '='x60,"\n";
  print "connecting $server\n";
  $exp = Expect->spawn("ssh bfausey\@$server") or die "Cannot spawn ssh: $!\n";
  $exp->expect(10,
               [
                'Password: $',
                sub {
                  my $fh = shift;
                  print $fh "NewDay1205\n";
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

#   $exp->send("sudo su - s1mq\n");
#   $exp->expect(10, '-re', qr'.*[$>#] $' );
#
#   $exp->send("imqcmd create dst -t q -n UDReplyQueue_$server\_d1c6_$server -o maxNumProducers=-1 -o maxNumActiveConsumers=-1 -b $server\:10000 -u admin -passfile /pegs/s1mq/scripts/.imq_passfile\n");
#   $exp->expect(30, '-re', qr'.*[$>#] $' );
#
#   $exp->send("imqcmd create dst -t q -n UDReplyQueue_$server\_d2c7_$server -o maxNumProducers=-1 -o maxNumActiveConsumers=-1 -b $server\:10000 -u admin -passfile /pegs/s1mq/scripts/.imq_passfile\n");
#   $exp->expect(30, '-re', qr'.*[$>#] $' );

   $exp->send("imqcmd list dst -t q -b $server\:10000 -u admin -passfile /pegs/s1mq/scripts/.imq_passfile\n");
   $exp->expect(10, '-re', qr'.*[$>#] $' );

   $exp->send("exit\n");
#   $exp->expect(10, '-re', qr'.*[$>#] $' );
#   $exp->send("exit\n");
}

exit;
