#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;


$server = 'udprodae09'; 
$ADMIN_PORT = ($ADMIN_PORT eq "") ? "5848" : $ADMIN_PORT;
$DAS = "uddas03-gf3";
$NODE = $DAS."_node_1";
$CLUSTER = $DAS."_cluster_5";
$INSTANCE = "d3c5_$server";
$max_instance = 4;
$ASADMIN = "/opt/glassfish3/glassfish/bin/asadmin";
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38080");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38081");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38082");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38083");

print "DAS=$DAS, NODE=$NODE, CLUSTER=$CLUSTER, INSTANCE=$INSTANCE\n";
foreach $ins (1..$max_instance) {
  print "$ins $INSTANCE\_$ins\n";
}
sleep(5);

  print '='x60,"\n";
  print "connecting $server\n";
  $exp = Expect->spawn("ssh bfausey\@$server") or die "Cannot spawn ssh: $!\n";
  $exp->expect(30,
               [
                'Password: $',
                sub {
                  my $fh = shift;
                  print $fh "NewDay0401\n";
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

   $exp->send("scp bfausey\@adsdevae01:/home/bfausey/jarfiles/*.jar /pegs/domains/$DAS/lib/ext\n");
   $exp->expect(60, 
                [
                  'Password: ',
                  sub {
                    my $fh = shift;
                    print $fh "NewDay0401\n";
                    exp_continue;
                  }
                ],
               '-re', qr'[$>#] $', #'
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

   $exp->send("$ASADMIN restart-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS\n");
   $exp->expect(60, 'Command restart-domain executed successfully' );

   $exp->send("$ASADMIN create-node-config --port $ADMIN_PORT --nodehost $server --installdir /opt/glassfish3 --nodedir /pegs/nodes $NODE\n"); 
   $exp->expect(60, 'Command create-node-config executed successfully' );

   $exp->send("$ASADMIN create-cluster --port $ADMIN_PORT $CLUSTER\n"); 
   $exp->expect(60, 'Command create-cluster executed successfully' );

   $exp->send("$ASADMIN start-cluster --port $ADMIN_PORT $CLUSTER\n"); 
   $exp->expect(60, 'Command start-cluster executed successfully' );

   foreach $ins (1..$max_instance) {
      $exp->send("$ASADMIN create-instance --port $ADMIN_PORT --node $NODE  --cluster $CLUSTER @SP[$ins - 1] $INSTANCE\_$ins\n"); 
      $exp->expect(60, 'Command create-instance executed successfully' );
      $exp->send("$ASADMIN start-instance --port $ADMIN_PORT $INSTANCE\_$ins\n"); 
      $exp->expect(60, 'Command start-instance executed successfully' );
   }

   $exp->send("$ASADMIN create-cluster --port $ADMIN_PORT tools_cluster_1\n"); 
   $exp->expect(60, 'Command create-cluster executed successfully' );
   $exp->send("$ASADMIN create-instance --port $ADMIN_PORT --node $NODE  --cluster tools_cluster_1 tools_instance_1\n"); 
   $exp->expect(60, 'Command create-instance executed successfully' );
   $exp->send("$ASADMIN start-instance --port $ADMIN_PORT tools_instance_1\n"); 
   $exp->expect(60, 'Command start-instance executed successfully' );

######################################################################################


   $exp->send("$ASADMIN list-nodes --port $ADMIN_PORT --long=true\n");
   $exp->expect(60, 'Command list-nodes-config executed successfully' );

   $exp->send("$ASADMIN list-instances -l --port $ADMIN_PORT\n");
   $exp->expect(60, 'Command list-nodes-config executed successfully' );

   $exp->send("$ASADMIN list-domains --domaindir /pegs/domains\n");
   $exp->expect(60, 'Command list-domain executed successfully' );

   $exp->send("exit\n");
   $exp->expect(10, '-re', qr'.*[$>#] $' );
   $exp->send("exit\n");

exit;
