#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days);
use Expect;

#push (@host,'udprodae01');
#push (@host,'udprodae02');
#push (@host,'udprodae03');
#push (@host,'udprodae04');
#push (@host,'udprodae05');
#push (@host,'udprodae06');
#push (@host,'udprodae07');
#push (@host,'udprodae09');
#push (@host,'udprodae11');
#push (@host,'udprodae12');
#push (@host,'udprodae13');
#push (@host,'udprodae14');

push (@host,'uddas01');
push (@host,'uddas02');
push (@host,'uswprodce13');
push (@host,'uswprodce13');
push (@host,'uswprodce14');
push (@host,'uswprodce15');

foreach $server (@host) {

  print '='x60,"\n";
  print "connecting $server\n";
#  $exp = Expect->spawn("ssh bfausey\@$server") or die "Cannot spawn ssh: $!\n";
  $exp = Expect->spawn("scp /home/bfausey/Marriott_Certificate_2014.p12 bfausey\@$server\:/tmp") or die "Cannot spawn scp: $!\n";
  $exp->expect(10,
               [
                'Password: $',
                sub {
                  my $fh = shift;
                  print $fh "NewDay0725\n";
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
}

exit;
