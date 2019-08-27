#!/bin/perl
use lib qw(/home/bfausey/perl/lib/lib/sun4-solaris-64int /home/bfausey/perl/lib/lib/site_perl);
use Date::Calc qw(Today Delta_Days Day_of_Week Add_Delta_Days Days_in_Month Week_of_Year);
use Spreadsheet::WriteExcel;

my $workbook = Spreadsheet::WriteExcel->new('calendar.xls');
# Add a worksheet
    $worksheet = $workbook->add_worksheet("Holidays");

$worksheet->set_column(0,1, 20);
$worksheet->set_column(2,25, 3);
foreach $r (0..30) {
  $worksheet->set_row($r, 16);
}
$worksheet->merge_cells('A1:B1');
$worksheet->merge_cells('C1:I1');
$worksheet->merge_cells('C8:I8');
$worksheet->merge_cells('C15:I15');
$worksheet->merge_cells('C22:I22');
$worksheet->merge_cells('J1:P1');
$worksheet->merge_cells('J8:P8');
$worksheet->merge_cells('J15:P15');
$worksheet->merge_cells('J22:P22');
$worksheet->merge_cells('Q1:W1');
$worksheet->merge_cells('Q8:W8');
$worksheet->merge_cells('Q15:W15');
$worksheet->merge_cells('Q22:W22');

# Set the formatting
$global_format = Spreadsheet::WriteExcel::Format->new();
$global_format->set_color('blue');
$global_format->set_font('Calibiri');
$global_format->set_size(8);
$global_format->set_align('left');

$string_format  = $workbook->add_format();
$string_format->copy($global_format);

$center_string_format  = $workbook->add_format();
$center_string_format->copy($global_format);
$center_string_format->set_align('center');

$date_format  = $workbook->add_format();
$date_format->copy($global_format);
$date_format->set_num_format('dddd mmmm d');

$heading = $workbook->add_format();
$heading->copy($global_format);
$heading->set_align('center');
$heading->set_bold();
$heading->set_color('red');
$heading->set_size(12);
$heading->set_merge();

$border = $workbook->add_format();
$border->copy($heading);
$border->set_border(6);
$border->set_border_color('black');


if (scalar(@ARGV) == 1) {
  $year = @ARGV[0];
} else {
  (@today_date) = Today();
  $year = @today_date[0];
}

push(@{$MONTH{0,2}},"JANUARY",1);
push(@{$MONTH{0,9}},"FEBRUARY",2);
push(@{$MONTH{0,16}},"MARCH",3);
push(@{$MONTH{7,2}},"APRIL",4);
push(@{$MONTH{7,9}},"MAY",5);
push(@{$MONTH{7,16}},"JUNE",6);
push(@{$MONTH{14,2}},"JULY",7);
push(@{$MONTH{14,9}},"AUGUST",8);
push(@{$MONTH{14,16}},"SEPTEMBER",9);
push(@{$MONTH{21,2}},"OCTOBER",10);
push(@{$MONTH{21,9}},"NOVEMBER",11);
push(@{$MONTH{21,16}},"DECEMBER",12);

foreach $k (sort {$MONTH{$a}->[1] <=> $MONTH{$b}->[1]} (keys %MONTH)) {
  $k =~ m/(.*)\x1c(.*)/;
  $r=$1;
  $c=$2;
  $d=$2;
  $dow = (Day_of_Week($year,$MONTH{$k}->[1],1));
  $dow = ($dow == 7) ? 0 : $dow;
  $dom = (Days_in_Month($year,$MONTH{$k}->[1]));
  $r++;
  $wd=0;
  $md=1;
  foreach $mc (1..42) {
     if (($wd >= $dow) && ($md <= $dom)) {
       push(@{$MONTH{$r,$c}},$md,$MONTH{$k}->[1],65);
       $md++;
     }
     $c++;
     $wd++;
     if (($mc % 7) == 0) {
       $r++;
       $c=$d;
     }
  }
}

$WEEK_DAYS{MONDAY}=1;
$WEEK_DAYS{TUESDAY}=2;
$WEEK_DAYS{WEDNESDAY}=3;
$WEEK_DAYS{THURSDAY}=4;
$WEEK_DAYS{FRIDAY}=5;
$WEEK_DAYS{SATURDAY}=6;
$WEEK_DAYS{SUNDAY}=7;

$row=1;
#New years day
push(@{$MONTH{$row,0}},1,1,sprintf("%04d-%02d-%02dT",$year,1,1));
push(@{$MONTH{$row,1}},1,1,"New Years Day");

$row++;
#MLK day
(@dte_find) = ($year,1,1);
do {
      $fdow = Day_of_Week(@dte_find);
      if ($fdow != $WEEK_DAYS{MONDAY}) {
        @dte_find = Add_Delta_Days(@dte_find,1);    
      }
} until ($fdow == $WEEK_DAYS{MONDAY});
#now that we got the first monday add 2 weeks
@dte_find = Add_Delta_Days(@dte_find,14);    
push(@{$MONTH{$row,0}},@dte_find[1],@dte_find[2],sprintf("%04d-%02d-%02dT",@dte_find[0],@dte_find[1],@dte_find[2]));
push(@{$MONTH{$row,1}},@dte_find[1],@dte_find[2],"Martin Luther King Day");


$row++;
#presidents day
(@dte_find) = ($year,2,1);
do {
      $fdow = Day_of_Week(@dte_find);
      if ($fdow != $WEEK_DAYS{MONDAY}) {
        @dte_find = Add_Delta_Days(@dte_find,1);    
      }
} until ($fdow == $WEEK_DAYS{MONDAY});
#now that we got the first monday add 2 weeks
@dte_find = Add_Delta_Days(@dte_find,14);    
push(@{$MONTH{$row,0}},@dte_find[1],@dte_find[2],sprintf("%04d-%02d-%02dT",@dte_find[0],@dte_find[1],@dte_find[2]));
push(@{$MONTH{$row,1}},@dte_find[1],@dte_find[2],"Presidents Day");


$row++;

#easter
  $g = int((($year % 19) + 1));
  $c = int((($year / 100) + 1));
  $x = int(((3 * $c / 4) - 12));
  $z = int((((8 * $c + 5) / 25) - 5));
  $d = int(((5 * $year / 4) - $x - 10));
  $e = int(((11 * $g + 20 + $z - $x) % 30));
  $e += 1 if ((($e == 25) && ($g > 11)) || ($e == 24));
  $n = (44 - $e);
  $n += 30 if ($n < 21);
  $n = int(($n + 7 - (($d + $n) % 7)));
  if ($n <= 31) {
    push(@{$MONTH{$row,0}},3,$n,sprintf("%04d-%02d-%02dT",$year,3,$n));
    push(@{$MONTH{$row,1}},3,$n,"Easter");
  } else {
    push(@{$MONTH{$row,0}},4,($n-31),sprintf("%04d-%02d-%02dT",$year,4,($n-31)));
    push(@{$MONTH{$row,1}},4,($n-31),"Easter");
  }


$row++;
#memorial day
(@dte_find) = ($year,5,31);
do {
      $fdow = Day_of_Week(@dte_find);
      if ($fdow != $WEEK_DAYS{MONDAY}) {
        @dte_find = Add_Delta_Days(@dte_find,-1);    
      }
} until ($fdow == $WEEK_DAYS{MONDAY});
push(@{$MONTH{$row,0}},@dte_find[1],@dte_find[2],sprintf("%04d-%02d-%02dT",@dte_find[0],@dte_find[1],@dte_find[2]));
push(@{$MONTH{$row,1}},@dte_find[1],@dte_find[2],"Memorial Day");

$row++;
#indenpendance day
push(@{$MONTH{$row,0}},7,4,sprintf("%04d-%02d-%02dT",$year,7,4));
push(@{$MONTH{$row,1}},7,4,"Indenpendance Day");

$row++;
#labor day
(@dte_find) = ($year,9,1);
do {
      $fdow = Day_of_Week(@dte_find);
      if ($fdow != $WEEK_DAYS{MONDAY}) {
        @dte_find = Add_Delta_Days(@dte_find,1);    
      }
} until ($fdow == $WEEK_DAYS{MONDAY});
push(@{$MONTH{$row,0}},@dte_find[1],@dte_find[2],sprintf("%04d-%02d-%02dT",@dte_find[0],@dte_find[1],@dte_find[2]));
push(@{$MONTH{$row,1}},@dte_find[1],@dte_find[2],"Labor Day");


$row++;
#thanksgiving day
(@dte_find) = ($year,11,1);
do {
      $fdow = Day_of_Week(@dte_find);
      if ($fdow != $WEEK_DAYS{THURSDAY}) {
        @dte_find = Add_Delta_Days(@dte_find,1);    
      }
} until ($fdow == $WEEK_DAYS{THURSDAY});
#now that we got the first thursday add 3 weeks
@dte_find = Add_Delta_Days(@dte_find,21);    
push(@{$MONTH{$row,0}},@dte_find[1],@dte_find[2],sprintf("%04d-%02d-%02dT",@dte_find[0],@dte_find[1],@dte_find[2]));
push(@{$MONTH{$row,1}},@dte_find[1],@dte_find[2],"Thanksgiving Day");

$row++;
@dte_find = Add_Delta_Days(@dte_find,1);    
push(@{$MONTH{$row,0}},@dte_find[1],@dte_find[2],sprintf("%04d-%02d-%02dT",@dte_find[0],@dte_find[1],@dte_find[2]));
push(@{$MONTH{$row,1}},@dte_find[1],@dte_find[2],"Black Friday");

$row++;
#christmas day
push(@{$MONTH{$row,0}},12,25,sprintf("%04d-%02d-%02dT",$year,12,25));
push(@{$MONTH{$row,1}},12,25,"Christmas Day");


foreach $r (0..28) {
  foreach $c (0..23) {
    foreach $m (1..$row) {
      if (($MONTH{$m,0}->[0] == $MONTH{$r,$c}->[1]) && ($MONTH{$m,0}->[1] == $MONTH{$r,$c}->[0])) {
        $MONTH{$r,$c}->[2] = 13 if ($c != 0 && $c != 1);
      }
    }
    if ($r > 0) {
      $worksheet->write_date_time($r,$c, $MONTH{$r,$c}->[2], $date_format) if ($c == 0);
      $worksheet->write($r,$c, $MONTH{$r,$c}->[2], $string_format) if ($c == 1);
    }
    if (($r != 0) && ($r != 7) && ($r != 14) && ($r != 21)) {
      if (($r == 28) && ($c != 23)) {
        $csf = $workbook->add_format();
        $csf->copy($center_string_format);
        $csf->set_top(6);
        $csf->set_border_color('black');
        $worksheet->write($r,$c, '',$csf) if (($c != 0) && ($c != 1));
      }
      if ((($c == 2) || ($c == 9) || ($c == 16) || ($c == 23))) {
        $csf = $workbook->add_format();
        $csf->copy($center_string_format);
        $csf->set_left(6);
        $csf->set_border_color('black');
        $csf->set_bg_color($MONTH{$r,$c}->[2]);
        $worksheet->write($r,$c, "$MONTH{$r,$c}->[0]",$csf) if ($r != 28);
      } else {
        $csf = $workbook->add_format();
        $csf->copy($center_string_format);
        $csf->set_bg_color($MONTH{$r,$c}->[2]);
        $worksheet->write($r,$c, "$MONTH{$r,$c}->[0]",$csf) if ($r != 28);
      }
    } else {
      if ($c != 23) {
        $worksheet->write($r,$c, "$MONTH{$r,$c}->[0]", $border) if ($c == 2 || $c == 9 || $c == 16);
        $worksheet->write($r,$c, "$year Holidays", $border) if ($c == 0 && $r == 0);
        if (($c != 0) && (($c == 1) && ($r == 0))) {
          $worksheet->write($r,$c, '',$border);
        } else {
          $worksheet->write($r,$c, '',$border) if ($c != 0 && $c != 1 && $c != 2 && $c != 9 && $c != 16);
        }
      }
    }
  }
}

$workbook->close();

exit;
