#!/usr/bin/perl
#
# Reads in a properties file in the form of:
#
# BEFORE_CODE_DOMAIN|BEFORE_CODE_TYPE|BEFORE_CODE_VALUE|BEFORE_SHORT_DESC|XREF_TYPE|AFTER_CODE_DOMAIN|AFTER_CODE_TYPE|AFTER_CODE_VALUE|AFTER_SHORT_DESC|MODIFY_USER
#
# and builds an output file of insert statements to create all these t$codes 
#  and T$code_xref
#
#  Where BEFORE is what you want to translate from and AFTER is what you want
#  to translate to.  For example, BEFORE can be the OTA values with AFTER as
#   the AMF values, as in this example:
#
# OTA|Error|742|ID required|OTA TO GDS|GDS|Error|CCN09|ID REQUIRED|amervick
#

# we need our properties file on the command line
if ("" eq $ARGV[0]) {
 print "No property file specified\n";
 exit (0);
}

print "Enter ticket number\n";
$ticket = <STDIN>;
chomp($ticket);

open (CODES, "$ARGV[0]");
open (OUT, ">$ticket.sql");

while ($line = <CODES>) {
  chop $line;
  next if $line =~ /\#/;
  ($BEFORE_CODE_DOMAIN, $BEFORE_CODE_TYPE, $BEFORE_CODE_VALUE, $BEFORE_SHORT_DESC, $XREF_TYPE, $AFTER_CODE_DOMAIN, $AFTER_CODE_TYPE, $AFTER_CODE_VALUE, $AFTER_SHORT_DESC, $MODIFY_USER) = split(/\|/, $line);
  # Build the lookup codes update
  print OUT "INSERT into t\$codes\n";
  print OUT "(CODE_ID,CODE_DOMAIN,CODE_TYPE,CODE_VALUE,SHORT_DESC,MODIFY_USER, MODIFY_TS)";
  print OUT "\nSELECT max(code_id)+1, '$BEFORE_CODE_DOMAIN', '$BEFORE_CODE_TYPE',";
  print OUT "'$BEFORE_CODE_VALUE', '$BEFORE_SHORT_DESC',\n\t";
  print OUT "'$MODIFY_USER', extend(current, year to second)\n";
  print OUT "FROM t\$codes;\n\n";
# Verify the insert
  print OUT "SELECT * from t\$codes\n";
  print OUT "WHERE code_value='$BEFORE_CODE_VALUE'\n";
  print OUT "AND code_type='$BEFORE_CODE_TYPE'\n";
  print OUT "AND code_domain='$BEFORE_CODE_DOMAIN';\n\n\n";


  # Build the conversion codes update
  print OUT "INSERT into t\$codes\n";
  print OUT "(CODE_ID,CODE_DOMAIN,CODE_TYPE,CODE_VALUE,SHORT_DESC,MODIFY_USER, MODIFY_TS)";
  print OUT "\nSELECT max(code_id)+1, '$AFTER_CODE_DOMAIN', '$AFTER_CODE_TYPE',";
  print OUT "'$AFTER_CODE_VALUE', '$AFTER_SHORT_DESC',\n\t";
  print OUT "'$MODIFY_USER', extend(current, year to second)\n";
  print OUT "FROM t\$codes;\n\n";
# Verify the insert
  print OUT "SELECT * from t\$codes\n";
  print OUT "WHERE code_value='$AFTER_CODE_VALUE'\n";
  print OUT "AND code_type='$AFTER_CODE_TYPE'\n";
  print OUT "AND code_domain='$AFTER_CODE_DOMAIN';\n\n\n";



  # load the exref table
  print OUT "INSERT into t\$code_xref\n";
  print OUT "(T\$CODE_XREF_UID,CODE_ID,XREF_TYPE,XREF_CODE_ID,MODIFY_USER, MODIFY_TS)\n";
  print OUT "SELECT max(x.T\$CODE_XREF_UID)+1,\n";
  print OUT "b4.code_id,'$XREF_TYPE',ftr.code_id,\n\t";
  print OUT "'$MODIFY_USER', extend(current, year to second)\n";
  print OUT "FROM t\$code_xref x, t\$codes b4, t\$codes ftr\n";
  print OUT "WHERE \t b4.CODE_DOMAIN = '$BEFORE_CODE_DOMAIN'\n\t";
  print OUT "and b4.CODE_TYPE = '$BEFORE_CODE_TYPE'\n\t";
  print OUT "and b4.CODE_VALUE = '$BEFORE_CODE_VALUE'\n\t";
  print OUT "and ftr.CODE_DOMAIN = '$AFTER_CODE_DOMAIN'\n\t";
  print OUT "and ftr.CODE_TYPE = '$AFTER_CODE_TYPE'\n\t";
  print OUT "and ftr.CODE_VALUE = '$AFTER_CODE_VALUE'\n\t" ;
  print OUT "GROUP BY 2,3,4,5,6;\n\n";

  # Verify the load
  print OUT "SELECT x.* FROM ";
  print OUT "t\$code_xref x, t\$codes b4, t\$codes ftr\n";
  print OUT "WHERE x.code_id = b4.code_id and x.xref_code_id = ftr.code_id\n";
  print OUT "AND x.xref_type='$XREF_TYPE'\n";
  print OUT "AND b4.CODE_DOMAIN = '$BEFORE_CODE_DOMAIN'\n\t";
  print OUT "AND b4.CODE_TYPE = '$BEFORE_CODE_TYPE'\n\t";
  print OUT "AND b4.CODE_VALUE = '$BEFORE_CODE_VALUE'\n\t";
  print OUT "AND ftr.CODE_DOMAIN = '$AFTER_CODE_DOMAIN'\n\t";
  print OUT "AND ftr.CODE_TYPE = '$AFTER_CODE_TYPE'\n\t";
  print OUT "AND ftr.CODE_VALUE = '$AFTER_CODE_VALUE';\n\n\n" ;
}

close(CODES);
close(OUT);
printf("\nDone...\n");
