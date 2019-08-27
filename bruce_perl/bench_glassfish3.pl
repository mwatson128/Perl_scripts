#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;

$server = 'bench13'; 
$ADMIN_PORT = ($ADMIN_PORT eq "") ? "5848" : $ADMIN_PORT;
$DAS = "dasbench13-gf3";
$NODE = "_node";
push (@CLUSTER, "ud_cluster_1");
push (@CLUSTER, "ud_cluster_2");
push (@CLUSTER, "ud_cluster_3");
push (@CLUSTER, "ud_cluster_4");
push (@TARGET,'benchae01');
push (@TARGET,'benchae02');
push (@TARGET,'benchae04');
push (@INSTANCE,"udc1_bench");
push (@INSTANCE,"udc2_bench");
push (@INSTANCE,"udc3_bench");
push (@INSTANCE,"udc4_bench");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38080");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38081");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38082");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38083");

$ASADMIN = "/opt/glassfish3/glassfish/bin/asadmin";
  
####--Creating Clusters
#
#    $ASADMIN setup-ssh --port $ADMIN_PORT @TARGET[$ct]
#    $ASADMIN enable-secure-admin --host @TARGET[$ct] --port $ADMIN_PORT
#    $ASADMIN restart-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS 
#    $ASADMIN create-node-ssh --port $ADMIN_PORT --nodehost @TARGET[$ct] --installdir /opt/glassfish3 --nodedir /pegs/nodes $tgnode
#    $ASADMIN create-instance --port $ADMIN_PORT --node $tgnode  --cluster @CLUSTER[$insctr] $ins\_$pre$num 
#asadmin create-instance --port 5848 --node bench13_node  --cluster ud_cluster_1 --systemproperties HTTP_LISTENER_PORT=38080 udc1_bench_13
#asadmin create-instance --port 5848 --node bench13_node  --cluster ud_cluster_2 --systemproperties HTTP_LISTENER_PORT=38081 udc2_bench_13#  
#
####--Done!

print "$DAS\n";
foreach $ct (0..$#TARGET) {
    $tgnode = "@TARGET[$ct]$NODE";
    $num = unpack(x7a2,@TARGET[$ct]);
    print "$ASADMIN setup-ssh --port $ADMIN_PORT @TARGET[$ct]\n";
    print "$ASADMIN enable-secure-admin --host @TARGET[$ct] --port $ADMIN_PORT\n";
    print "$ASADMIN restart-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS\n";
    print "$ASADMIN create-node-ssh --port $ADMIN_PORT --nodehost @TARGET[$ct] --installdir /opt/glassfish3 --nodedir /pegs/nodes $tgnode\n";
     $insctr = 0;
     foreach $ins (@INSTANCE) {
        print "$ASADMIN create-instance --port $ADMIN_PORT --node $tgnode  --cluster @CLUSTER[$insctr] @SP[$insctr] $ins\_$num\n";
        $insctr++;
     }
}


######################################################################################


   print "$ASADMIN list-nodes --port $ADMIN_PORT --long=true\n";
   print "$ASADMIN list-instances -l --port $ADMIN_PORT\n";
   print "$ASADMIN list-domains --domaindir /pegs/domains\n";
exit;
