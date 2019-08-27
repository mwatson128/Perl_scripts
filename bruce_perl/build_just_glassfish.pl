#!/bin/perl
use lib qw(/home/mwatson/lib/lib/sun4-solaris-64int /home/mwatson/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;


$server = 'pegsdev17'; 
$ADMIN_PORT = ($ADMIN_PORT eq "") ? "5848" : $ADMIN_PORT;
$DAS = "pegsdev17-gf3";
$ASADMIN = "/uswdev/glassfish3/glassfish/bin/asadmin";

  print '='x60,"\n";
  print "connecting $server\n";
  $exp = Expect->spawn("ssh mwatson\@$server") or die "Cannot spawn ssh: $!\n";
  $exp->expect(30,
               [
                'Password: $',
                sub {
                  my $fh = shift;
                  print $fh "Three1ron\n";
                  exp_continue;
                }
               ],
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

   $exp->send("$ASADMIN create-domain --domainproperties domain.adminPort=$ADMIN_PORT:domain.instancePort=48080 --keytooloptions \"CN=$server\" --savelogin=true --domaindir /pegs/domains $DAS\n");
   $exp->expect(60, 
                [
                  'Enter admin user name \[Enter to accept default \"admin\" / no password\]>',
                  sub {
                    my $fh = shift;
                    print $fh "admin\n";
                    exp_continue;
                  }
                ],
                [
                  'Enter the admin password \[Enter to accept default of no password\]>',
                  sub {
                    my $fh = shift;
                    print $fh "comet.emp\n";
                    exp_continue;
                  }
                ],
                [
                  'Enter the admin password again>',
                  sub {
                    my $fh = shift;
                    print $fh "comet.emp\n";
                    exp_continue;
                  }
                ],
               'Command create-domain executed successfully', 
              );


   $exp->send("$ASADMIN start-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS\n");
   $exp->expect(60, 'Command start-domain executed successfully' );

   $exp->send("$ASADMIN --host $server --port $ADMIN_PORT enable-secure-admin\n");
   $exp->expect(60, 
                [
                  'Enter admin user name>',
                  sub {
                    my $fh = shift;
                    print $fh "admin\n";
                    exp_continue;
                  }
                ],
                [
                  'Enter admin password for user \"admin\">',
                  sub {
                    my $fh = shift;
                    print $fh "comet.emp\n";
                    exp_continue;
                  }
                ],
                'Command enable-secure-admin executed successfully', 
              );

#   $exp->send("scp mwatson\@adsdevae01:/home/mwatson/jarfiles/*.jar /pegs/domains/$DAS/lib/ext\n");
#   $exp->expect(10,'Password: $');
#   $exp->send("NewDay0725\r");
#   $exp->expect(10, '-re', qr'.*[$>#] $' );

   $exp->send("$ASADMIN restart-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS\n");
   $exp->expect(60, 'Command restart-domain executed successfully' );

######################################################################################


   $exp->send("exit\n");
   $exp->expect(10, '-re', qr'.*[$>#] $' );
   $exp->send("exit\n");

exit;
