#!/bin/perl 
# (]$[) %M%:%I% | CDATE=%G% %U%
# Take an .h file and organize it into segment and fields.
#

############################################################################
# GLOBALS
############################################################################


$IFP = "< $ARGV[0]";

$FLD1 = "< /home/mwatson/bin/fldlmts.txt";
$FLD2 = "< /home/mwatson/bin/fldlmts2.txt";



############################################################################
# Preload
############################################################################

open FLD1 or die "can't open FLD1\n";

while (<FLD1>) {
  chomp;
  @fld_1 = split /\|/;
  $length_hash{$fld_1[0]} = $fld_1[1];
}
close FLD1;

open FLD2 or die "can't open FLD2\n";

while (<FLD2>) {
  chomp;
  @fld_2 = split /\|/;
  $length_hash{$fld_2[0]} = $fld_2[1];
}
close FLD2;


############################################################################
# MAIN
############################################################################

open IFP or die "Can't open $ARGV[0].";

$i_struct = 0;
$o_struct = 0;

while (<IFP>) {

  chomp;
  next if ($o_struct);
  next if /^#|^$/;
  next if /^\/\*/;
  next if /^\*\*/;

  if (/^struct/) {

    $i_struct = 1;
    @nm1 = split /struct/;
    @nm2 = split /_s/, $nm1[1];
    printf "Segment %s\n", uc $nm2[0];
    print "-------------------------------------------------------------\n";
    print " AMF   Type   Field name                    Description\n";
    print "-------------------------------------------------------------\n";

  }
  elsif (/struct {/) {
    $o_struct = 1;
  }
  else {
    
    next if (/struct/); 
    @pt1 = split /;/;
    @pt2 = split / +/,$pt1[0];
    $pt1[1] =~ s{\s*\z}{}gmsx; # remove leading whitespace
    @pt3 = split /\)/,$pt1[1];
    @pt4 = split /\*\//,$pt3[1];
    @amf_c = split /\(/, $pt3[0];

    $code = $pt2[2];
    $descr = $pt4[0];

    if ("char" eq $pt2[1]) { 
      $typ = "CHAR"; 
    }
    elsif ("short" eq $pt2[1] || "long" eq $pt2[1]) {
      $typ = "NUMB";
    }
    elsif ("float" eq $pt2[1]) {
      $typ = "DECI";
    }
    elsif ("utf8_t" eq $pt2[1]) {
      $typ = "UTF8";
    }

    # substitute numbers for defines in c_names
    if ($code) {
      @pt5 = split /\[/, $code;
      if ($pt5[1]) {
        @pt6 = split /\]/, $pt5[1];

	if ("UTF8" eq $typ) {
	  @pt6_1 = split /\*/, $pt6[0];
          $c_name = $pt5[0] . "[" . $length_hash{$pt6_1[0]};
	  if ($pt6_1[1]) {
            $c_name .= " * " . $pt6_1[1] . "]";
	  }
	  else {
            $c_name .= "]";
	  }
        }
	else {
          $c_name = $pt5[0] . "[" . $length_hash{$pt6[0]} . "]";
	}
	if ($pt5[2]) {
          @pt7 = split /\]/, $pt5[2];
	  if ("UTF8" eq $typ) {
	    @pt7_1 = split /\*/, $pt7[0];
	    $c_name = $pt5[0] . "[" . $length_hash{$pt7_1[0]};
	    if ($pt7_1[1]) {
	      $c_name .= " * " . $pt7_1[1] . "]";
	    }
	    else {
	      $c_name .= "]";
	    }
	  }
	  else {
            $c_name .= "[" . $length_hash{$pt7[0]} . "]";
	  }
	}
      }
      else {
        $c_name = $pt5[0];
      }
    }
        
    if ($amf_c[1]) {
      #print "  $amf_c[1]   $typ  $c_name  -  $descr \n";
      printf " %3s | %4s | %-27.27s | %-32.32s\n", $amf_c[1], $typ, $c_name,
             $descr;
    }
  }
}

close IFP;

