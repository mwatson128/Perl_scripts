#!/usr/local/bin/perl

use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl /home/bfausey/perl/lib /home/kdaniel/modules/WEBSERVER/lib);
use Net::LDAP;
use Net::LDAP::Util qw(ldap_error_text ldap_error_name);

  $host = "ldap-prod";
  $port = "389";
  $base = "o=Pegasus Systems";
  $attrs = "['mail']";
  $ecode = "";
  $ename = "";
  $etext = "";

  undef(@email_addrs);

  # Generate the query string based on distribution lists selected
  $filter = "(&(objectclass=person)(|";
  foreach $group (@distlists) {
    $filter .= "(notificationgroups=$group)";
  }
  $filter .= "))";

  # Create a Net::LDAP object and bind to the server
  if ($ldap = Net::LDAP->new($host)) {}
  else {
    # Display an error to the browser and die
    print "error on new\n";
    exit;
  }
  $ldap->bind;

  # Query for the desired info
  $query = $ldap->search(base => $base,
                         port => $port,
                         attrs => $attrs,
                         filter => $filter);

  # Get error info if error occurred
  if ($query->code > 0) {
    $ecode = $query->code;
    $ename = ldap_error_name($query->code);
    $etext = ldap_error_text($query->code);
    die "$ecode $ename $etext\n";
  }

  # Parse the data from LDAP
  $result = $query->as_struct;
  @dn_array = keys %$result;
  foreach $dn (@dn_array) {
    print "$dn $$result{$dn}\n";
  }# end foreach

  # Disconnect from the LDAP server
  $ldap->unbind;
exit(0);
