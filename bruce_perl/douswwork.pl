#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;

push (@host,'uswprodce13');
push (@host,'uswprodce14');
push (@host,'uswprodce15');
push (@host,'uddas01');
push (@host,'uddas02');


($day,$month,$year) = (localtime)[3,4,5];
$month++;
$year+=1900;

$copycmd = sprintf("cp keystore.jks keystore.jks_%d%02d%02d",$year,$month,$day);
$listcmd = "/usr/java/bin/keytool -list -v -keystore keystore.jks | grep \"^[AV]\" | grep -v \"Auth\"";
$importcmd = "/usr/java/bin/keytool -importkeystore  -srckeystore /pegs/home/sun1/Marriott_Certificate_2014.p12 -destkeystore keystore.jks -srcstoretype pkcs12 -deststoretype jks -srcstorepass P3gasus2014 -deststorepass comet.emp -v";

push(@cluster,'-1/d1c1_');
push(@cluster,'-1/d1c2_');
push(@cluster,'-2/d2c3_');
push(@cluster,'-2/d2c4_');

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
   $exp->expect(5, '-re', qr'.*[$>#] $' );
   
   if ($server =~ m/uddas(.*)/) {

       $exp->send("cd /pegs/domains/otadas$1/config\n");
       $exp->expect(5, '-re', qr'.*[$>#] $' );
#       $exp->send("$copycmd\n");
#       $exp->expect(10, '-re', qr'.*[$>#] $' );
#       $exp->send("$importcmd\n");
#       $exp->expect(10, '-re', qr'.*[$>#] $' );
       $exp->send("$listcmd\n");
       $exp->expect(5, 'password: $');
       $exp->send("comet.emp\r");
       $exp->expect(5, '-re', qr'.*[$>#] $' );

   } else {
       $server =~ m/uswprodce(.*)/;
       $servernum = $1;
       foreach $cl (@cluster) {
          $exp->send("cd /pegs/nodeagents/$server\_node_agent$cl$servernum/config\n");
          $exp->expect(5, '-re', qr'.*[$>#] $' );
#          $exp->send("$copycmd\n");
#          $exp->expect(10, '-re', qr'.*[$>#] $' );
#          $exp->send("$importcmd\n");
#          $exp->expect(10, '-re', qr'.*[$>#] $' );
          $exp->send("$listcmd\n");
          $exp->expect(5, 'password: $');
          $exp->send("comet.emp\r");
          $exp->expect(5, '-re', qr'.*[$>#] $' );
       }

   }

   $exp->send("exit\n");
   $exp->expect(5, '-re', qr'.*[$>#] $' );
   $exp->send("exit\n");
}

exit;
