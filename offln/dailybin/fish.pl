## (]$[) fish.pl:1.1 | CDATE=03/12/03 17:14:49
##
##
##             Copyright (C) 1999 Pegasus Systems, Inc.
##                  All Rights Reserved
##
###########################################################################
##  This is a perl include to give perl scripts Fred Fish debug feeling  ##
##  output files for troubleshooting purposes.                           ## 
###########################################################################

sub DBUG_FILE;
sub DBUG_PRINT;
sub DBUG_ENTER;
sub DBUG_VOID_RETURN;
sub DBUG_RETURN;
sub DBUG_ON;
sub DBUG_OFF;

$dbug_file = "./debug.fish";
$DBUG_F = "OFF";

sub DBUG_FILE {
  close DBUG;
  system "rm $dbug_file 2> /dev/null";
  $dbug_file = $_[0];
}

sub DBUG_PRINT {
  my ($f_name, $pr_format, @pr_args) = @_;

  if ($DBUG_F eq "ON") {
    printf DBUG sprintf("%s: %s\n", "|  " x ($#f_stack + 1) . $f_name, 
           $pr_format), @pr_args;
  }
}

sub DBUG_ENTER {
  
  my $f_name = $_[0];
  push @f_stack, $f_name;

  if ($DBUG_F eq "ON") {
    printf DBUG "%s>%s\n", "|  " x $#f_stack, $f_name;
  }
}

sub DBUG_VOID_RETURN {
  
  my $f_name = pop @f_stack;
  if ($DBUG_F eq "ON") {
    printf DBUG "%s<%s\n", "|  " x ($#f_stack + 1), $f_name;
  }
}

sub DBUG_ON {
  $DBUG_F = "ON";
  close DBUG;
  open DBUG, "> $dbug_file" or die "Can't open $dbug_file\n";
}

sub DBUG_OFF {
  $DBUG_F = "OFF";
  close DBUG;
}
