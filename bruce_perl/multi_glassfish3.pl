#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;

#### REMINDER change $server and $DAS
#### REMINDER change clusters 1,2,6 or 3,4,7
#### REMINDER change instance d1c 1,2,6 or d2c 3,4,7
#### REMINDER change node to 1 or 2 

$server = 'uddas02-gf3'; 
$ADMIN_PORT = ($ADMIN_PORT eq "") ? "5848" : $ADMIN_PORT;
$DAS = "uddas02-gf3";
$NODE = "_node_2";
push (@CLUSTER, $DAS."_cluster_3");
push (@CLUSTER, $DAS."_cluster_4");
push (@CLUSTER, $DAS."_cluster_7");
push (@TARGET,'udprodae01');
push (@TARGET,'udprodae02');
push (@TARGET,'udprodae03');
push (@TARGET,'udprodae04');
push (@TARGET,'udprodae05');
push (@TARGET,'udprodae06');
push (@TARGET,'udprodae07');
push (@TARGET,'udprodae11');
push (@TARGET,'udprodae12');
push (@TARGET,'udprodae13');
push (@TARGET,'udprodae14');

push (@INSTANCE,"d2c3");
push (@INSTANCE,"d2c4");
push (@INSTANCE,"d2c7");

push (@SP," ");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38080");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38081");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38082");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38083");
push (@SP," ");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38084");
push (@SP,"--systemproperties HTTP_LISTENER_PORT=38085");

$ASADMIN = "/opt/glassfish3/glassfish/bin/asadmin";
  
####--Creating Clusters
#
#    $ASADMIN setup-ssh --port $ADMIN_PORT @TARGET[$ct]
#    $ASADMIN enable-secure-admin --host @TARGET[$ct] --port $ADMIN_PORT
#    $ASADMIN restart-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS 
#    $ASADMIN create-node-ssh --port $ADMIN_PORT --nodehost @TARGET[$ct] --installdir /opt/glassfish3 --nodedir /pegs/nodes $tgnode
#    $ASADMIN create-instance --port $ADMIN_PORT --node $tgnode  --cluster @CLUSTER[$insctr] $ins\_$pre$num 
#  
#
####--Done!

#print "$DAS\n";
#foreach $clus (@CLUSTER) {
#  print "$ASADMIN create-cluster --port $ADMIN_PORT $clus\n";
#}
foreach $ct (0..$#TARGET) {
  ($pre, $num) = unpack(a2x6a2,@TARGET[$ct]); 
  $tgnode = "@TARGET[$ct]$NODE";
#  print "$ASADMIN setup-ssh --port $ADMIN_PORT @TARGET[$ct]\n";
#  print "$ASADMIN enable-secure-admin --host @TARGET[$ct] --port $ADMIN_PORT\n";
#  print "$ASADMIN restart-domain --port $ADMIN_PORT --domaindir /pegs/domains $DAS\n";
#  print "$ASADMIN create-node-ssh --port $ADMIN_PORT --nodehost @TARGET[$ct] --installdir /opt/glassfish3 --nodedir /pegs/nodes $tgnode\n";
  if (int($num) < 10) {
     $insctr = 0;
     foreach $ins (@INSTANCE) {
        ($innum) = unpack(x3a1,$ins); 
        print "$ASADMIN delete-instance --port $ADMIN_PORT --node $tgnode  --cluster @CLUSTER[$insctr] $ins\_instance_$pre$num\n";
        print "$ASADMIN create-instance --port $ADMIN_PORT --node $tgnode @SP[$innum] --cluster @CLUSTER[$insctr] $ins\_@TARGET[$ct]\n";
        $insctr++;
     }
  } else {
     $insctr = 0;
     foreach $ins (@INSTANCE) {
        $new = int(unpack(x3a1,$ins));
        if ($new < 5) {
           print "$ASADMIN delete-instance --port $ADMIN_PORT --node $tgnode  --cluster @CLUSTER[$insctr] $ins\_instance_$pre$num\n";
           print "$ASADMIN create-instance --port $ADMIN_PORT --node $tgnode  @SP[$new] --cluster @CLUSTER[$insctr] $ins\_@TARGET[$ct]\n";
           $insctr++;
        }
     }
  }
}


######################################################################################


   print "$ASADMIN list-nodes --port $ADMIN_PORT --long=true\n";
   print "$ASADMIN list-instances -l --port $ADMIN_PORT\n";
   print "$ASADMIN list-domains --domaindir /pegs/domains\n";
exit;






















#@@@@

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
