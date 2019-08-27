#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;


$server1 = 'adstoolsae01'; 
$server2 = 'adstoolsae02'; 
$ADMIN_PORT = ($ADMIN_PORT eq "") ? "5848" : $ADMIN_PORT;
$DAS = "toolsdas01-gf3";
$NODE = $DAS."_node";
$CLUSTER = "tools_cluster_1";
$INSTANCE = "tools_instance";
$max_instance = 2;
$ASADMIN = "/opt/glassfish3/glassfish/bin/asadmin";
$SP = "--systemproperties HTTP_LISTENER_PORT=38080";

print "DAS=$DAS, NODE=$NODE, CLUSTER=$CLUSTER, INSTANCE=$INSTANCE\n";
foreach $ins (1..$max_instance) {
  print "$ins $NODE\_$ins\n";
  print "$ins contains $INSTANCE\_$ins\n";
}
sleep(5);


   print "$ASADMIN create-domain --domainproperties domain.adminPort=$ADMIN_PORT:domain.instancePort=48080 --keytooloptions \"CN=$server1\" --savelogin=true --domaindir /pegs/domains $DAS\n";
   print "scp bfausey\@adsdevae01:/home/bfausey/jarfiles/*.jar /pegs/domains/$DAS/lib/ext\n";

   print "$ASADMIN start-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS\n";

   print "$ASADMIN --host $server1 --port $ADMIN_PORT enable-secure-admin\n";

   print "$ASADMIN restart-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS\n";

   print "$ASADMIN create-node-config --port $ADMIN_PORT --nodehost $server1 --installdir /opt/glassfish3 --nodedir /pegs/nodes $NODE\_1\n"; 

   print "$ASADMIN setup-ssh --port 5848 $server2\n";

   print "$ASADMIN create-node-ssh --port 5848 --nodehost $server2 --installdir /opt/glassfish3 --nodedir /pegs/nodes $NODE\_2\n";

   print "$ASADMIN create-cluster --port $ADMIN_PORT $CLUSTER\n"; 

   print "$ASADMIN start-cluster --port $ADMIN_PORT $CLUSTER\n"; 

   print "$ASADMIN create-instance --port $ADMIN_PORT --node $NODE\_1  --cluster $CLUSTER $SP $INSTANCE\_1\n";
   print "$ASADMIN create-instance --port $ADMIN_PORT --node $NODE\_2  --cluster $CLUSTER $SP $INSTANCE\_2\n";

######################################################################################


   print "$ASADMIN list-nodes --port $ADMIN_PORT --long=true\n";

   print "$ASADMIN list-instances -l --port $ADMIN_PORT\n";

   print "$ASADMIN list-domains --domaindir /pegs/domains\n";


exit;
