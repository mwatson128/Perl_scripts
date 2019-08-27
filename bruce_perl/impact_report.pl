#!/opt/dba/perl5.8.4/bin/perl

#******************************************************************************#
#*                          Wells Fargo Mortgage                              *#
#*                    SMS - Secondary Marketing System                        *#
#******************************************************************************#
#*  Program Name:  impact_report.pl                                           *#
#*                                                                            *#
#*  Description:  This program will create a spread sheet to show the new     *#
#*                values after the run of the rules.                          *#
#*                                                                            *#
#*  Tables Accessed : loan, loan_sale, trans_journal, impact_column,          *#
#*                    sql_column, sql_join                                    *#
#*                    *PLUS* the tables choose by the users                   *#
#*                                                                            *#
#*  Parameters:                                                               *#
#*               User ID        ASCII String      User name to look for       *#
#******************************************************************************#
#*  Change History                                                            *#
#*                                                                            *#
#*  Chg  Rel   Programmer      Date       Description                         *#
#*  ---  ---   ----------      ----       ---------------------------         *#
#*  0    3.08  Bruce Fausey   05/21/08    Original Delivery                   *#
#******************************************************************************#

# Required Perl modules

use strict;
use Sybase::DBlib;
use Date::Calc qw(Today Today_and_Now);

# Global variables used in this script

# strings
my $dbs='';
my $user='';
my $pswd='';
my $baseDBserver='';
my $baseDB='';
my $activeDBserver='';
my $activeDB='';
my $cmd='';
my $key='';
my $tdate='';
my $downloadfile='';

# integers
my $count=0;
my $max_user_cols=0;
my $max_sales_errors=0;
my $max_fh=0;
my $max_fn=0;
my $max_loans=0;

# hash tables
my %column_info;
my %user_columns;
my %tables;
my %core_data;
my %user_data;
my %spec_feat_data;
my %row_loan_numbers;

# arrays
my @today_date=();
my @row=();

# Open the database


$count = @ARGV;
die "Arguments to be passed:Username Password DBserver DB DBserver DB\n" if ( $count < 3 );

$user = @ARGV[0];
$pswd = @ARGV[1];
$baseDBserver = @ARGV[2];
$baseDB = (@ARGV[3] ne '') ? @ARGV[3] : 'sms';
$activeDBserver = (@ARGV[4] ne '') ? @ARGV[4] : @ARGV[2]; 
$activeDB = (@ARGV[5] ne '') ? @ARGV[5] : 'sms';

$dbs = new Sybase::DBlib $user, $pswd, $baseDBserver || 
     die "connection to $baseDBserver failed $!\n";

# build core data fields and problem table for column headings

(@today_date) = Today_and_Now();
$tdate=sprintf("%04d-%02d-%02dT%02d:%02d:%02dC",@today_date[0],@today_date[1],@today_date[2],@today_date[3],@today_date[4],@today_date[5]);

$downloadfile=sprintf("/tmp/%s.IR.xml",$user);

print "$downloadfile\n";

$tables{chan_mkg_ref}="chan_mkg_ref, loan where chan_mkg_ref.clnt_id = loan.clnt_id and  loan.ln_serv_nbr =";
$tables{commitment}="commitment, loan where commitment.cmt_id = loan.cmt_id and  loan.ln_serv_nbr =";
$tables{product}="product, loan where product.prod_lne_cde = loan.prod_lne_cde and  loan.ln_serv_nbr =";
$tables{trade}="trade,commitment,loan where trade.trd_id = commitment.trd_id and commitment.cmt_id  = loan.cmt_id and loan.ln_serv_nbr =";



$cmd = sprintf("select sql_col_nme,case sql_col_dtyp_nme when 'datetime' then 's25' when 'float' then 's24' when 'decimal' then 's24' else 's23' end from %s..sql_column where sql_col_nme in  ('ln_serv_nbr', 'ln_agy_cnform_ind', 'ln_cfrm_lst_yr_ind', 'ln_hme_acc_ind', 'sale_catg_cde', 'sale_trgt_catg_cde', 'ln_sle_fh_elig_ind', 'ln_sle_fn_elig_ind', 'ln_fhlmc_del_fee', 'ln_fnma_del_fee') and sql_col_prcss_typ_cde = 'esp'",$baseDB);
$dbs->dbcmd($cmd);
$dbs->dbsqlexec;
if ($dbs->dbresults == SUCCEED) {
  while (@row = $dbs->dbnextrow) {
    @row[0] =~ s/\s+$//;
    push(@{$column_info{ln_serv_nbr}},0,10,@row[1]) if (@row[0] =~ m/ln_serv_nbr/);
    push(@{$column_info{ln_agy_cnform_ind}},10,1,@row[1]) if (@row[0] =~ m/ln_agy_cnform_ind/);
    push(@{$column_info{ln_cfrm_lst_yr_ind}},11,1,@row[1]) if (@row[0] =~ m/ln_cfrm_lst_yr_ind/);
    push(@{$column_info{ln_hme_acc_ind}},12,1,@row[1]) if (@row[0] =~ m/ln_hme_acc_ind/);
    push(@{$column_info{orig_sale_catg_cde}},33,-1,@row[1]) if (@row[0] =~ m/sale_catg_cde/);
    push(@{$column_info{new_sale_catg_cde}},34,2,@row[1]) if (@row[0] =~ m/sale_catg_cde/);
    push(@{$column_info{orig_sale_trgt_catg_cde}},37,-1,@row[1]) if (@row[0] =~ m/sale_trgt_catg_cde/);
    push(@{$column_info{new_sale_trgt_catg_cde}},38,2,@row[1]) if (@row[0] =~ m/sale_trgt_catg_cde/);
    push(@{$column_info{ln_sle_fh_elig_ind}},40,1,@row[1]) if (@row[0] =~ m/ln_sle_fh_elig_ind/);
    push(@{$column_info{ln_sle_fn_elig_ind}},41,1,@row[1]) if (@row[0] =~ m/ln_sle_fn_elig_ind/);
    push(@{$column_info{ln_fhlmc_del_fee}},45,8,@row[1]) if (@row[0] =~ m/ln_fhlmc_del_fee/);
    push(@{$column_info{ln_fnma_del_fee}},53,8,@row[1]) if (@row[0] =~ m/ln_fnma_del_fee/);
  }
} else {
  close_and_exit("query failed $cmd\n");
}

push(@{$column_info{sales_errors}},61,(250-61),'s23');

$cmd = sprintf("select table_name,column_name,impact_column_nbr,case sql_col_dtyp_nme when 'datetime' then 's25' when 'float' then 's24' when 'decimal' then 's24' else 's23' end from %s..sql_column,%s..impact_column where sql_col_nme = column_name and sql_tbl_nme = table_name and sql_col_prcss_typ_cde = 'esp' and user_id = '%s'",$baseDB,$baseDB,$user);
$dbs->dbcmd($cmd);
$dbs->dbsqlexec;
if ($dbs->dbresults == SUCCEED) {
  while (@row = $dbs->dbnextrow) {
    $max_user_cols++;
    $user_columns{@row[1]}=@row[0];
    if (!exists $tables{@row[0]}) {
       $tables{@row[0]}="@row[0] where @row[0].ln_serv_nbr = "
    }
    push(@{$column_info{@row[1]}},(66+@row[2]),-1,@row[3]);
  }
} else {
  close_and_exit("query failed $cmd\n");
}


push(@{$column_info{spec_code}},501,6,'s23');

# close the base database and open the active database
# if the servers are the same don't do anything

if ($baseDBserver ne $activeDBserver) {
  $dbs->dbclose;
  $dbs = new Sybase::DBlib $user, $pswd, $activeDBserver || 
       die "connection to $activeDBserver failed $!\n";
}

get_impacted_loans();
write_spreadsheet();
close_and_exit("done\n");

#----------------------------------------------------------------

sub get_impacted_loans {

#get loan numbers from the transaction jounal
#sequence 0 == new category/loan number etc.
#sequence 1 == feature code information

my %trans_journal_txt;
my $seq;
my $prcss_nbr;
my $lst_prcss_nbr;
my $row_ctr=0;

  $cmd = sprintf("select prcss_entry_nbr,prcss_seq_nbr,trans_jrnl_txt from trans_journal where prcss_nme = 'smbuncom' and lst_upd_user_id = '%s'",$user);

  $dbs->dbcmd($cmd);
  $dbs->dbsqlexec;
  if ($dbs->dbresults == SUCCEED) {
    while (@row = $dbs->dbnextrow) {
     $trans_journal_txt{@row[0],@row[1]}="@row[2]";
    }
  } else {
    close_and_exit("query failed $cmd\n");
  }
  foreach $key (sort {$a cmp $b} (keys %trans_journal_txt)) {
    $key =~ m/(.*)\x1c(.*)/;
    $seq = $2;
    $prcss_nbr = $1;

    if ($prcss_nbr != $lst_prcss_nbr ) {
      $row_ctr++;
      $lst_prcss_nbr = $prcss_nbr;
    }
    
    if ( $seq == 0) {
      process_old_and_new_data("$trans_journal_txt{$key}",$row_ctr);
      $max_loans++;
    } else {
      process_spec_feat_code("$trans_journal_txt{$key}",$row_ctr);
    }
  }
}

#----------------------------------------------------------------

sub process_old_and_new_data {

my $col_ctr=0;
my $user_ctr=0;
my $ln_nbr;
my @sales_errors;

  $ln_nbr = unpack("x$column_info{ln_serv_nbr}->[0] a$column_info{ln_serv_nbr}->[1]",@_[0]);
  print "Processing Loan Number $ln_nbr\n"; 
  $row_loan_numbers{$ln_nbr}=$max_loans;
  foreach $key (sort {$column_info{$a}->[0] <=> $column_info{$b}->[0]} (keys %column_info)) {
    if ($column_info{$key}->[0] < 60 ) {
      if ($key =~ m/orig_(.*)/ ) {
        $cmd = sprintf("select %s from loan_sale where ln_serv_nbr = %s",$1,$ln_nbr);
        $dbs->dbcmd($cmd);
        $dbs->dbsqlexec;
        if ($dbs->dbresults == SUCCEED) {
          while (@row = $dbs->dbnextrow) {
            push(@{$core_data{$ln_nbr,$col_ctr}},@row[0],$column_info{$key}->[2]);
          }
        } else {
          close_and_exit("query failed $cmd\n");
        }
        $col_ctr++;
      }
      if ($column_info{$key}->[1] > 0 ) {
         my $st = $column_info{$key}->[0];
         my $len = $column_info{$key}->[1];
         push(@{$core_data{$ln_nbr,$col_ctr}},unpack("x$st a$len",@_[0]),$column_info{$key}->[2]);
         $col_ctr++;
      }
    } else {
      if ($column_info{$key}->[0] > 60 && $column_info{$key}->[0] < 65) {
        (@sales_errors)=split(' ',unpack("x$column_info{$key}->[0] a$column_info{$key}->[1]",@_[0]));
        $count = scalar @sales_errors;
        $max_sales_errors=(($max_sales_errors > $count) ? $max_sales_errors : $count);
        foreach my $se (@sales_errors) {
          push(@{$core_data{$ln_nbr,$col_ctr}},$se,$column_info{$key}->[2]);
          $col_ctr++;
        }
      }
      if ($column_info{$key}->[0] > 65 && $column_info{$key}->[0] < 500) {
        my $select='';
        if ($column_info{$key}->[2] eq 's25') {
          $select = "convert(char(10),$user_columns{$key}.$key,110)";
        } else {
          $select = "$user_columns{$key}.$key";
        }
        $cmd = sprintf("select distinct %s from %s %s",$select,$tables{$user_columns{$key}},$ln_nbr);
        my $bq=$user_ctr;
        $dbs->dbcmd($cmd);
        $dbs->dbsqlexec;
        if ($dbs->dbresults == SUCCEED) {
          while (@row = $dbs->dbnextrow) {
            push(@{$user_data{$ln_nbr,$user_ctr}},@row[0],$column_info{$key}->[2]);
            $user_ctr++;
          }
        } else {
          close_and_exit("query failed $cmd\n");
        }
        $user_ctr++ if ($bq == $user_ctr);
      }
    }
  }
}

#----------------------------------------------------------------

sub process_spec_feat_code {

my $ln_nbr;
my $fh_ctr=0;
my $fn_ctr=0;

  $ln_nbr = unpack("x$column_info{ln_serv_nbr}->[0] a$column_info{ln_serv_nbr}->[1]",@_[0]);
  for (my $ctr = 10; $ctr < length(@_[0]); $ctr += $column_info{spec_code}->[1]) {
    my $sfc = unpack("x$ctr a$column_info{spec_code}->[1]",@_[0]); 
    if (length($sfc) > 2) {
      $sfc =~ m/((FH-)|(FN-))(.*)/;
      $spec_feat_data{'FN',$ln_nbr,$fn_ctr}=$4,$fn_ctr++ if ($3);
      $spec_feat_data{'FH',$ln_nbr,$fh_ctr}=$4,$fh_ctr++ if ($2);
    }
  }
  $max_fh=(($max_fh > $fh_ctr) ? $max_fh : $fh_ctr);
  $max_fn=(($max_fn > $fn_ctr) ? $max_fn : $fn_ctr);
}

#----------------------------------------------------------------

sub write_spreadsheet {

#actually I am writing out an XML file that can open under Excel

my $fieldname;
my $col_cnt=0;
my $col=0;
my %format;

open(XMLFILE,">$downloadfile") || close_and_exit("Cannot open $downloadfile $!\n");

#XML file information
print XMLFILE <<EoT;
<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
 <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">
<!-- let the author = user and create date = current date -->
  <LastAuthor>$user</LastAuthor>
  <Created>$tdate</Created>
 </DocumentProperties>
 <Styles>
  <Style ss:ID="Default" ss:Name="Normal">
   <Alignment ss:Vertical="Bottom"/>
   <Borders/>
   <Font/>
   <Interior/>
   <NumberFormat/>
   <Protection/>
  </Style>
  <Style ss:ID="s22">
   <Alignment ss:Horizontal="CenterAcrossSelection" ss:Vertical="Center"
    ss:WrapText="1"/>
   <Font ss:FontName="Calibiri" ss:Color="#FF0000" ss:Bold="1"/>
  </Style>
  <Style ss:ID="s23">
   <Alignment ss:Horizontal="Left" ss:Vertical="Center"/>
   <Font ss:FontName="Calibiri" ss:Size="8" ss:Color="#0000FF"/>
  </Style>
  <Style ss:ID="s24">
   <Alignment ss:Horizontal="Right" ss:Vertical="Center"/>
   <Font ss:FontName="Calibiri" ss:Size="8" ss:Color="#0000FF"/>
   <NumberFormat ss:Format="#0.000"/>
  </Style>
  <Style ss:ID="s25">
   <Alignment ss:Horizontal="Left" ss:Vertical="Center"/>
   <Font ss:FontName="Calibiri" ss:Size="8" ss:Color="#0000FF"/>
   <NumberFormat ss:Format="m/d/yyyy"/>
  </Style>
  <Style ss:ID="s26">
   <Alignment ss:Horizontal="CenterAcrossSelection" ss:Vertical="Center"
    ss:WrapText="1"/>
   <Font ss:FontName="Calibiri" ss:Color="#339966" ss:Bold="1"/>
  </Style>
 </Styles>

 <Worksheet ss:Name="Impact Report">
EoT

#core columns including sale errors  and the number of user columns
$col_cnt = (12+$max_sales_errors+$max_user_cols);
print XMLFILE "  <Table ss:ExpandedColumnCount=\"$col_cnt\">\n";
$col_cnt--;
print XMLFILE "   <Column ss:AutoFitWidth=\"0\" ss:Width=\"72\" ss:Span=\"$col_cnt\"/>\n";
print XMLFILE "   <Row ss:AutoFitHeight=\"0\" ss:Height=\"25.0000\">\n";

#print the heading row
foreach $key (sort {$column_info{$a}->[0] <=> $column_info{$b}->[0]} (keys %column_info)) {
  $fieldname = $key;
  $fieldname =~ s/_/ /g;
  if ($column_info{$key}->[0] < 60 ) {
    print XMLFILE "<Cell ss:StyleID=\"s22\"><Data ss:Type=\"String\">$fieldname</Data></Cell>\n";
    $col++;
  }
  if (($column_info{$key}->[0] > 60 ) && ($column_info{$key}->[0] < 65)) {
    print XMLFILE "<Cell ss:StyleID=\"s22\"><Data ss:Type=\"String\">$fieldname</Data></Cell>\n";
    my $c = (($col+$max_sales_errors)-1);
    while ($col < $c) { 
      print XMLFILE "<Cell ss:StyleID=\"s22\"></Cell>\n";
      $col++;
    }
  }
  if (($column_info{$key}->[0] > 65) && ($column_info{$key}->[0] < 500)) {
    print XMLFILE "<Cell ss:StyleID=\"s26\"><Data ss:Type=\"String\">$fieldname</Data></Cell>\n";
    $col++;
  }
}
print XMLFILE "  </Row>\n";

#print the data rows
foreach my $ln (sort {$row_loan_numbers{$a} <=> $row_loan_numbers{$b}} (keys %row_loan_numbers)) {
  print XMLFILE "   <Row ss:AutoFitHeight=\"0\" ss:Height=\"25.0000\">\n";
  #13 core columns + max 18 sales errors
  foreach my $c (0..(13+18)) {
    if (exists $core_data{$ln,$c}) {
      my $type = ($core_data{$ln,$c}->[1] eq 's24') ? 'Number' : 'String';
      print XMLFILE "<Cell ss:StyleID=\"$core_data{$ln,$c}->[1]\"><Data ss:Type=\"$type\">$core_data{$ln,$c}->[0]</Data></Cell>\n";
    } else {
      if ($c < (12+$max_sales_errors)) {
        print XMLFILE "<Cell ss:StyleID=\"s23\"></Cell>\n";
      }
    }
  }
  foreach my $c (0..$max_user_cols) {
    if (exists $user_data{$ln,$c} ) { 
      my $type = ($user_data{$ln,$c}->[1] eq 's24') ? 'Number' : 'String';
      print XMLFILE "<Cell ss:StyleID=\"$user_data{$ln,$c}->[1]\"><Data ss:Type=\"$type\">$user_data{$ln,$c}->[0]</Data></Cell>\n";
    } else {
      if ($c <= ($max_user_cols - 1)) {
        print XMLFILE "<Cell ss:StyleID=\"s23\"></Cell>\n";
      }
    }
  }
  print XMLFILE "  </Row>\n";
}
#finished worksheet and start second work sheet.


print XMLFILE <<EoT;
  </Table>
  <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
   <Selected/>
   <FreezePanes/>
   <FrozenNoSplit/>
   <SplitHorizontal>1</SplitHorizontal>
   <TopRowBottomPane>1</TopRowBottomPane>
   <SplitVertical>1</SplitVertical>
   <LeftColumnRightPane>1</LeftColumnRightPane>
   <ActivePane>0</ActivePane>
   <Panes>
    <Pane>
     <Number>3</Number>
    </Pane>
    <Pane>
     <Number>1</Number>
     <ActiveCol>0</ActiveCol>
    </Pane>
    <Pane>
     <Number>2</Number>
     <ActiveRow>0</ActiveRow>
    </Pane>
    <Pane>
     <Number>0</Number>
     <ActiveCol>0</ActiveCol>
    </Pane>
   </Panes>
   <ProtectObjects>False</ProtectObjects>
   <ProtectScenarios>False</ProtectScenarios>
  </WorksheetOptions>
 </Worksheet>
 <Worksheet ss:Name="Special Feature Codes">
EoT

#max fannie mae and freddie mac codes plus loan number
$col_cnt = ($max_fh+$max_fn+1);
print XMLFILE "  <Table ss:ExpandedColumnCount=\"$col_cnt\">\n";
$col_cnt--;
print XMLFILE "   <Column ss:AutoFitWidth=\"0\" ss:Width=\"52\" ss:Span=\"$col_cnt\"/>\n";
print XMLFILE "   <Row ss:AutoFitHeight=\"0\" ss:Height=\"25.0000\">\n";


##add special feature codes headings to work sheet 2
  print XMLFILE "<Cell ss:StyleID=\"s22\"><Data ss:Type=\"String\">ln serv nbr</Data></Cell>\n";
  foreach my $c (1..$max_fh) {
    print XMLFILE "<Cell ss:StyleID=\"s22\"><Data ss:Type=\"String\">fhlmc sfc</Data></Cell>\n";
  }
  foreach my $c (1..$max_fn) {
    print XMLFILE "<Cell ss:StyleID=\"s22\"><Data ss:Type=\"String\">fnma sfc</Data></Cell>\n";
  }
  print XMLFILE "   </Row>\n";

  #add special feature codes data  to work sheet 2
  foreach $key (sort {$row_loan_numbers{$a} <=> $row_loan_numbers{$b}} (keys %row_loan_numbers)) {
    print XMLFILE "   <Row ss:AutoFitHeight=\"0\" ss:Height=\"25.0000\">\n";
      print XMLFILE "<Cell ss:StyleID=\"s23\"><Data ss:Type=\"String\">$key</Data></Cell>\n";
    foreach my $c (0..($max_fh-1)) {
      print XMLFILE "<Cell ss:StyleID=\"s23\"><Data ss:Type=\"String\">$spec_feat_data{'FH',$key,$c}</Data></Cell>\n";
    }
    foreach my $c (0..($max_fn-1)) {
      print XMLFILE "<Cell ss:StyleID=\"s23\"><Data ss:Type=\"String\">$spec_feat_data{'FN',$key,$c}</Data></Cell>\n";
    }
    print XMLFILE "   </Row>\n";
  }



print XMLFILE <<EoT;
 </Table>
  <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
   <Selected/>
   <FreezePanes/>
   <FrozenNoSplit/>
   <SplitHorizontal>1</SplitHorizontal>
   <TopRowBottomPane>1</TopRowBottomPane>
   <SplitVertical>1</SplitVertical>
   <LeftColumnRightPane>1</LeftColumnRightPane>
   <ActivePane>0</ActivePane>
   <Panes>
    <Pane>
     <Number>3</Number>
    </Pane>
    <Pane>
     <Number>1</Number>
     <ActiveCol>0</ActiveCol>
    </Pane>
    <Pane>
     <Number>2</Number>
     <ActiveRow>0</ActiveRow>
    </Pane>
    <Pane>
     <Number>0</Number>
     <ActiveRow>0</ActiveRow>
     <ActiveCol>0</ActiveCol>
    </Pane>
   </Panes>
   <ProtectObjects>False</ProtectObjects>
   <ProtectScenarios>False</ProtectScenarios>
  </WorksheetOptions>
 </Worksheet>
</Workbook>
EoT

##close the XML file
close(XMLFILE);
}

#----------------------------------------------------------------

sub close_and_exit {
print @_;
$dbs->dbclose;
exit;
}
