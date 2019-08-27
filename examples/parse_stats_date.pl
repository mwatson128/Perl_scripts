#!/usr/local/bin/perl
##  This script will use the stats output of LGPER 
##  (]$[) parse_stats.pl:1.24 | CDATE=03/07/08 10:13:30
##
## Format of stats file:
## DATE TIME|GDS|HRS|RQT|RPT|UTT|
## NUM_MSG|NUM_TMO|NUM_TPP|GIL|GOL|HIL|HOL|NRW|GRT|HRT|TRT|
##
## New Format of stats file:
## DATE TIME|GDS|HRS|RQT|RPT|UTT|TRQ|TRP
## NUM_MSG|NUM_TMO|NUM_TPP|GIL|GOL|HIL|HOL|NRW|GRT|HRT|TRT|

use Getopt::Long;

###########################
##  Forward declarations  #
###########################

sub parse_cmdline;
sub parse_stats_file;
sub update_counters;
sub comp_stats;
sub dump_stats;
sub dump_final_stats;
sub init_stats;
sub clear_stats;
sub open_stats_file;

############
##  Main  ##
############

# Initialize variables
init_stats();

# Parse the command line arguements
parse_cmdline();

# Open the stats file
open_stats_file();

# Parse stats file
parse_stats_file();
     
# If we are producing a summary report dump the final stats
if ($summary_flag eq "TRUE") {
  dump_final_stats();
}

# Close the file and exit
close FIL;
exit; 

#####################################
##  Subroutine:  parse_stats_file  ##
#####################################
sub parse_stats_file {

  # Load the first line
  $line = <FIL>;

  # Keep reading and processing lines until we have a reason to exit.
  while ($exit_flag ne "TRUE") {

    # We hit an iteration delimiter
    if ($line =~ /^---/) {

      # Grab the date from the line
      $line =~ /(\d+\/\d+\/\d+ \d+:\d+:\d+)/;
      $iter_time = $1;
  
      # If the time matches 23:59, lets get ready to exit
      if ($iter_time =~ /^\d+\/\d+\/\d+ 23:59/) {
        $exit_flag = "TRUE";
      }

      # Capture start / stop times if summary
      if ($summary_flag eq "TRUE") {
        if ($first_time eq "TRUE") {
          $first_time = $iter_time;
        }
      }
      $last_time = $iter_time;
     
      # Compute the stats for this interval
      comp_stats();
     
      # If we are not producing a summary report, print iterative stats 
      if ($summary_flag ne "TRUE") {
        dump_stats();
      }

      # Clear iterative stats
      clear_stats();
    }

    # Process statistics
    else {

      # Old format has 18 fields and the new format has 20 fields
      # Split the line into variables
      if (18 == ($num_flds = split(/\|/, $line))) {
        (
         $tstamp, $gds, $hrs, $rqt, $rpt, $utt,
         $num_msg, $num_tmo, $num_tpp,
         $avg_gil, $avg_gol,
         $avg_hil, $avg_hol,
         $avg_nrw,
         $avg_grt, $avg_hrt, $avg_trt,
        ) = split(/\|/, $line);
        $trq = 1;
        $trp = 1;
      }
      else {
        (
         $tstamp, $gds, $hrs, $rqt, $rpt, $utt, $trq, $trp,
         $num_msg, $num_tmo, $num_tpp,
         $avg_gil, $avg_gol,
         $avg_hil, $avg_hol,
         $avg_nrw,
         $avg_grt, $avg_hrt, $avg_trt,
        ) = split(/\|/, $line);
      }

      $update_counters = "ON";

      # Filter on HRS, GDS, TRQ,  and TRP
      # Check filters and if we have a match
      if ($flag_gds eq "ON" && $gds !~ /$filter_gds/) {
        $update_counters = "OFF";
      }
      if ($flag_hrs eq "ON" && $hrs !~ /$filter_hrs/) {
        $update_counters = "OFF";
      }
      if ($flag_trq eq "ON" && $trq != $filter_trq) {
        $update_counters = "OFF";
      }
      if ($flag_trp eq "ON" && $trp != $filter_trp) {
        $update_counters = "OFF";
      }

      if ($update_counters eq "ON") {
        update_counters;
      }
    }

    if (!($line = <FIL>)) {
       $exit_flag = "TRUE";
    }
  }
}

####################################
##  Subroutine:  update_counters  ##
####################################
sub update_counters {

  # Calculate the dwell time based on the command line options
  # Check if we want USW dwell time
  if ($dwell_type eq "u") {
    $dwell_time = $avg_grt - $avg_hrt;
  }

  # Check for GDS round trip time
  elsif ($dwell_type eq "g") {
    $dwell_time = $avg_grt; 
  }

  # Check for HRS round trip time.
  elsif ($dwell_type eq "h") {
    $dwell_time = $avg_hrt;
  }

  # Check for TPP round trip time.
  elsif ($dwell_type eq "t") {
    $dwell_time = $avg_trt;
  }

  # Check for system dwell time.
  elsif ($dwell_type eq "s") {
    $dwell_time = ($avg_grt - $avg_hrt - $avg_trt);
  }

  # If Dwell times > 60 seconds then they are timeouts
  # Set Dwell time to 0 so they are not counted.
  if ($dwell_time >= 60) {
    $dwell_time = -1;
  }

  # Check for BOOK type message.
  if ($rpt =~ /BOOKRP/) {

    # Increment BOOK dwell time if the dwell_time is greater than 0
    if ($dwell_time > 0) {
      $dwell{BOOK} += $dwell_time * $num_msg;
    }

    # Update the message counts for BOOK
    $sum{BOOK} += $num_msg;

    if ($summary_flag eq "TRUE") {

      # Update the GDS Input Length for BOOK
      $gil{BOOK} += $avg_gil * $num_msg;

      # Update the GDS output Length for BOOK
      $gol{BOOK} += $avg_gol * $num_msg;

      # Update the HRS Input Length for BOOK
      $hil{BOOK} += $avg_hil * $num_msg;

      # Update the HRS output Length for BOOK
      $hol{BOOK} += $avg_hol * $num_msg;
    }
  } 

  # Check for PALS type message.
  elsif ($rpt =~ /PALSRP|PNLSRP/) {
    if ($dwell_time > 0) {
      $dwell{PALS} += $dwell_time * $num_msg;
    }

    # Update message counts for PALS
    $sum{PALS} += $num_msg;

    if ($summary_flag eq "TRUE") {

      # Update the GDS Input Length for PALS
      $gil{PALS} += $avg_gil * $num_msg;

      # Update the GDS output Length for PALS
      $gol{PALS} += $avg_gol * $num_msg;

      # Update the HRS Input Length for PALS
      $hil{PALS} += $avg_hil * $num_msg;

      # Update the HRS output Length for PALS
      $hol{PALS} += $avg_hol * $num_msg;
    }
  }

  # Check for RPIN type messages.
  elsif ($rpt =~ /RPINRP|PRINRP|RTINRP/) {
    if ($dwell_time > 0) {
      $dwell{RPIN} += $dwell_time * $num_msg;
    }

    # Update message counts for RPIN
    $sum{RPIN} += $num_msg;

    if ($summary_flag eq "TRUE") {

      # Update the GDS Input Length for RPIN
      $gil{RPIN} += $avg_gil * $num_msg;

      # Update the GDS output Length for RPIN
      $gol{RPIN} += $avg_gol * $num_msg;

      # Update the HRS Input Length for RPIN
      $hil{RPIN} += $avg_hil * $num_msg;

      # Update the HRS output Length for RPIN
      $hol{RPIN} += $avg_hol * $num_msg;
    }
  }

  # Check for AALS type messages.
  elsif ($rpt =~ /AALSRP/) {
    if ($dwell_time > 0) {
      $dwell{AALS} += $dwell_time * $num_msg;
    }
      
    # Update message counts for AALS
    $sum{AALS} += $num_msg;

    if ($summary_flag eq "TRUE") {

      # Update the GDS Input Length for AALS
      $gil{AALS} += $avg_gil * $num_msg;

      # Update the GDS output Length for AALS
      $gol{AALS} += $avg_gol * $num_msg;

      # Update the HRS Input Length for AALS
      $hil{AALS} += $avg_hil * $num_msg;

      # Update the HRS output Length for AALS
      $hol{AALS} += $avg_hol * $num_msg;
    }
  }
  # Check for RSIN type messages.
  elsif ($rpt =~ /RSINRP/) {
    $sum{RSIN} += $num_msg;
  }

  # Check for ERRRP and ERRREP type messages.
  elsif ($rpt =~ /ERRRP|ERRREP|PALSRQ|RPINRQ|PRINRQ|AALSRQ|ADDCHG|BOOKRQ|DELETE/) {
    $sum{ERRR} += $num_msg;

    if ($summary_flag eq "TRUE") {

      # Update the GDS Input Length for ERRR
      $gil{ERRR} += $avg_gil * $num_msg;

      # Update the GDS output Length for ERRR
      $gol{ERRR} += $avg_gol * $num_msg;

      # Update the HRS Input Length for ERRR
      $hil{ERRR} += $avg_hil * $num_msg;

      # Update the HRS output Length for ERRR
      $hol{ERRR} += $avg_hol * $num_msg;
    }
  }

  # Check for AVSTAT type messages.
  elsif ($rpt =~ /AVSTAT/) {
    $sum{AVST} += $num_msg;

    if ($summary_flag eq "TRUE") {

      # Update the GDS Input Length for AVST
      $gil{AVST} += $avg_gil * $num_msg;

      # Update the GDS output Length for AVST
      $gol{AVST} += $avg_gol * $num_msg;

      # Update the HRS Input Length for AVST
      $hil{AVST} += $avg_hil * $num_msg;

      # Update the HRS output Length for AVST
      $hol{AVST} += $avg_hol * $num_msg;
    }
  }

  # Check for DBUP (Database Update) type messages.
  elsif ($rpt =~ /PRINUP|PRSDUP|RTYUP/) {
    $sum{DBUP} += $num_msg;

    if ($summary_flag eq "TRUE") {

      # Update the GDS Input Length for DBUP
      $gil{DBUP} += $avg_gil * $num_msg;

      # Update the GDS output Length for DBUP
      $gol{DBUP} += $avg_gol * $num_msg;

      # Update the HRS Input Length for DBUP
      $hil{DBUP} += $avg_hil * $num_msg;

      # Update the HRS output Length for DBUP
      $hol{DBUP} += $avg_hol * $num_msg;
    }
  }

  # Uknown message
  else {
    printf STDERR "Unknown MSG TYPE:  %s %s\n", $rqt, $line;
  }
}

##############################
## Subroutine:  comp_stats  ##
##############################
sub comp_stats {

  # Incremenet the stats file iteration count
  $num_iters++;
  
  # If we counted some books, calculate the average response time
  if ($sum{BOOK} != 0) {
    $book_avg = $dwell{BOOK} / $sum{BOOK};

    # If we are producing a summary report, check for MAX/MIN dwell values
    if ($summary_flag eq "TRUE") {
      if ($book_avg > 0) {
        if ($book_avg > $MAX{BOOK_DWELL}) {
          $MAX{BOOK_DWELL} = $book_avg;
        }
        if ($book_avg < $MIN{BOOK_DWELL}) {
          $MIN{BOOK_DWELL} = $book_avg;
        }
      }
    }
  }

  # If we counted some pals, calculate the average response time
  if ($sum{PALS} != 0) {
    $pals_avg = $dwell{PALS} / $sum{PALS};

    # If we are producing a summary report, check for MAX/MIN dwell values
    if ($summary_flag eq "TRUE") {
      if ($pals_avg > 0) {
        if ($pals_avg > $MAX{PALS_DWELL}) {
          $MAX{PALS_DWELL} = $pals_avg;
        }
        if ($pals_avg < $MIN{PALS_DWELL}) {
          $MIN{PALS_DWELL} = $pals_avg;
        }
      }
    }
  }

  # If we counted some rpins, calculate the average response time
  if ($sum{RPIN} != 0) {
    $rpin_avg = $dwell{RPIN} / $sum{RPIN};

    # If we are producing a summary report, check for MAX/MIN dwell values
    if ($summary_flag eq "TRUE") {
      if ($rpin_avg > 0) {
        if ($rpin_avg > $MAX{RPIN_DWELL}) {
          $MAX{RPIN_DWELL} = $rpin_avg;
        }
        if ($rpin_avg < $MIN{RPIN_DWELL}) {
          $MIN{RPIN_DWELL} = $rpin_avg;
        }
      }
    }
  }

  # If we counted some aals, calculate the average response time
  if ($sum{AALS} != 0) {
    $aals_avg = $dwell{AALS} / $sum{AALS};

    # If we are producing a summary report, check for MAX/MIN dwell values
    if ($summary_flag eq "TRUE") {
      if ($aals_avg > 0) {
        if ($aals_avg > $MAX{AALS_DWELL}) {
          $MAX{AALS_DWELL} = $aals_avg;
        }
        if ($aals_avg < $MIN{AALS_DWELL}) {
          $MIN{AALS_DWELL} = $aals_avg;
        }
      }
    }
  }

  # If we are producing a summary report, keep track of total numbers
  if ($summary_flag eq "TRUE") {
    for $msg_type (%dwell) {
      $total_dwell{$msg_type} += $dwell{$msg_type};
    }
    for $msg_type (%sum) {
      $total_sum{$msg_type} += $sum{$msg_type};
    }
    for $msg_type (%gil) {
      $total_gil{$msg_type} += $gil{$msg_type};
    }
    for $msg_type (%gol) {
      $total_gol{$msg_type} += $gol{$msg_type};
    }
    for $msg_type (%hil) {
      $total_hil{$msg_type} += $hil{$msg_type};
    }
    for $msg_type (%hol) {
      $total_hol{$msg_type} += $hol{$msg_type};
    }
  }

  # If we are producing a summary report, check for 
  # MAX/MIN GIL, GOL, HIL, HOL values
  if ($summary_flag eq "TRUE") {
  
    # If we counted some BOOKs, calculate the average GIL, GOL, HIL, HOL
    # and check for MAX/MIN values
    if ($sum{BOOK} != 0) {
      $gil_avg = $gil{BOOK} / $sum{BOOK};

      if ($gil_avg > 0) {
        if ($gil_avg > $MAX{BOOK_GIL}) {
          $MAX{BOOK_GIL} = $gil_avg;
        }
        if ($gil_avg < $MIN{BOOK_GIL}) {
          $MIN{BOOK_GIL} = $gil_avg;
        }
      }
      $gol_avg = $gol{BOOK} / $sum{BOOK};

      if ($gol_avg > 0) {
        if ($gol_avg > $MAX{BOOK_GOL}) {
          $MAX{BOOK_GOL} = $gol_avg;
        }
        if ($gol_avg < $MIN{BOOK_GOL}) {
          $MIN{BOOK_GOL} = $gol_avg;
        }
      }
      $hil_avg = $hil{BOOK} / $sum{BOOK};

      if ($hil_avg > 0) {
        if ($hil_avg > $MAX{BOOK_HIL}) {
          $MAX{BOOK_HIL} = $hil_avg;
        }
        if ($hil_avg < $MIN{BOOK_HIL}) {
          $MIN{BOOK_HIL} = $hil_avg;
        }
      }
      $hol_avg = $hol{BOOK} / $sum{BOOK};

      if ($hol_avg > 0) {
        if ($hol_avg > $MAX{BOOK_HOL}) {
          $MAX{BOOK_HOL} = $hol_avg;
        }
        if ($hol_avg < $MIN{BOOK_HOL}) {
          $MIN{BOOK_HOL} = $hol_avg;
        }
      }
    }
  
    # If we counted some PALS, calculate the average GIL, GOL, HIL, HOL
    # and check for MAX/MIN values
    if ($sum{PALS} != 0) {
      $gil_avg = $gil{PALS} / $sum{PALS};

      if ($gil_avg > 0) {
        if ($gil_avg > $MAX{PALS_GIL}) {
          $MAX{PALS_GIL} = $gil_avg;
        }
        if ($gil_avg < $MIN{PALS_GIL}) {
          $MIN{PALS_GIL} = $gil_avg;
        }
      }
      $gol_avg = $gol{PALS} / $sum{PALS};

      if ($gol_avg > 0) {
        if ($gol_avg > $MAX{PALS_GOL}) {
          $MAX{PALS_GOL} = $gol_avg;
        }
        if ($gol_avg < $MIN{PALS_GOL}) {
          $MIN{PALS_GOL} = $gol_avg;
        }
      }
      $hil_avg = $hil{PALS} / $sum{PALS};

      if ($hil_avg > 0) {
        if ($hil_avg > $MAX{PALS_HIL}) {
          $MAX{PALS_HIL} = $hil_avg;
        }
        if ($hil_avg < $MIN{PALS_HIL}) {
          $MIN{PALS_HIL} = $hil_avg;
        }
      }
      $hol_avg = $hol{PALS} / $sum{PALS};

      if ($hol_avg > 0) {
        if ($hol_avg > $MAX{PALS_HOL}) {
          $MAX{PALS_HOL} = $hol_avg;
        }
        if ($hol_avg < $MIN{PALS_HOL}) {
          $MIN{PALS_HOL} = $hol_avg;
        }
      }
    }
  
    # If we counted some RPINs, calculate the average GIL, GOL, HIL, HOL
    # and check for MAX/MIN values
    if ($sum{RPIN} != 0) {
      $gil_avg = $gil{RPIN} / $sum{RPIN};

      if ($gil_avg > 0) {
        if ($gil_avg > $MAX{RPIN_GIL}) {
          $MAX{RPIN_GIL} = $gil_avg;
        }
        if ($gil_avg < $MIN{RPIN_GIL}) {
          $MIN{RPIN_GIL} = $gil_avg;
        }
      }
      $gol_avg = $gol{RPIN} / $sum{RPIN};

      if ($gol_avg > 0) {
        if ($gol_avg > $MAX{RPIN_GOL}) {
          $MAX{RPIN_GOL} = $gol_avg;
        }
        if ($gol_avg < $MIN{RPIN_GOL}) {
          $MIN{RPIN_GOL} = $gol_avg;
        }
      }
      $hil_avg = $hil{RPIN} / $sum{RPIN};

      if ($hil_avg > 0) {
        if ($hil_avg > $MAX{RPIN_HIL}) {
          $MAX{RPIN_HIL} = $hil_avg;
        }
        if ($hil_avg < $MIN{RPIN_HIL}) {
          $MIN{RPIN_HIL} = $hil_avg;
        }
      }
      $hol_avg = $hol{RPIN} / $sum{RPIN};

      if ($hol_avg > 0) {
        if ($hol_avg > $MAX{RPIN_HOL}) {
          $MAX{RPIN_HOL} = $hol_avg;
        }
        if ($hol_avg < $MIN{RPIN_HOL}) {
          $MIN{RPIN_HOL} = $hol_avg;
        }
      }
    }
  
    # If we counted some AALSs, calculate the average GIL, GOL, HIL, HOL
    # and check for MAX/MIN values
    if ($sum{AALS} != 0) {
      $gil_avg = $gil{AALS} / $sum{AALS};

      if ($gil_avg > 0) {
        if ($gil_avg > $MAX{AALS_GIL}) {
          $MAX{AALS_GIL} = $gil_avg;
        }
        if ($gil_avg < $MIN{AALS_GIL}) {
          $MIN{AALS_GIL} = $gil_avg;
        }
      }
      $gol_avg = $gol{AALS} / $sum{AALS};

      if ($gol_avg > 0) {
        if ($gol_avg > $MAX{AALS_GOL}) {
          $MAX{AALS_GOL} = $gol_avg;
        }
        if ($gol_avg < $MIN{AALS_GOL}) {
          $MIN{AALS_GOL} = $gol_avg;
        }
      }
      $hil_avg = $hil{AALS} / $sum{AALS};

      if ($hil_avg > 0) {
        if ($hil_avg > $MAX{AALS_HIL}) {
          $MAX{AALS_HIL} = $hil_avg;
        }
        if ($hil_avg < $MIN{AALS_HIL}) {
          $MIN{AALS_HIL} = $hil_avg;
        }
      }
      $hol_avg = $hol{AALS} / $sum{AALS};

      if ($hol_avg > 0) {
        if ($hol_avg > $MAX{AALS_HOL}) {
          $MAX{AALS_HOL} = $hol_avg;
        }
        if ($hol_avg < $MIN{AALS_HOL}) {
          $MIN{AALS_HOL} = $hol_avg;
        }
      }
    }
  
    # If we counted some ERRRs, calculate the average GIL, GOL, HIL, HOL
    # and check for MAX/MIN values
    if ($sum{ERRR} != 0) {
      $gil_avg = $gil{ERRR} / $sum{ERRR};

      if ($gil_avg > 0) {
        if ($gil_avg > $MAX{ERRR_GIL}) {
          $MAX{ERRR_GIL} = $gil_avg;
        }
        if ($gil_avg < $MIN{ERRR_GIL}) {
          $MIN{ERRR_GIL} = $gil_avg;
        }
      }
      $gol_avg = $gol{ERRR} / $sum{ERRR};

      if ($gol_avg > 0) {
        if ($gol_avg > $MAX{ERRR_GOL}) {
          $MAX{ERRR_GOL} = $gol_avg;
        }
        if ($gol_avg < $MIN{ERRR_GOL}) {
          $MIN{ERRR_GOL} = $gol_avg;
        }
      }
      $hil_avg = $hil{ERRR} / $sum{ERRR};

      if ($hil_avg > 0) {
        if ($hil_avg > $MAX{ERRR_HIL}) {
          $MAX{ERRR_HIL} = $hil_avg;
        }
        if ($hil_avg < $MIN{ERRR_HIL}) {
          $MIN{ERRR_HIL} = $hil_avg;
        }
      }
      $hol_avg = $hol{ERRR} / $sum{ERRR};

      if ($hol_avg > 0) {
        if ($hol_avg > $MAX{ERRR_HOL}) {
          $MAX{ERRR_HOL} = $hol_avg;
        }
        if ($hol_avg < $MIN{ERRR_HOL}) {
          $MIN{ERRR_HOL} = $hol_avg;
        }
      }
    }
  
    # If we counted some AVSTs, calculate the average GIL, GOL, HIL, HOL
    # and check for MAX/MIN values
    if ($sum{AVST} != 0) {
      $gil_avg = $gil{AVST} / $sum{AVST};

      if ($gil_avg > 0) {
        if ($gil_avg > $MAX{AVST_GIL}) {
          $MAX{AVST_GIL} = $gil_avg;
        }
        if ($gil_avg < $MIN{AVST_GIL}) {
          $MIN{AVST_GIL} = $gil_avg;
        }
      }
      $gol_avg = $gol{AVST} / $sum{AVST};

      if ($gol_avg > 0) {
        if ($gol_avg > $MAX{AVST_GOL}) {
          $MAX{AVST_GOL} = $gol_avg;
        }
        if ($gol_avg < $MIN{AVST_GOL}) {
          $MIN{AVST_GOL} = $gol_avg;
        }
      }
      $hil_avg = $hil{AVST} / $sum{AVST};

      if ($hil_avg > 0) {
        if ($hil_avg > $MAX{AVST_HIL}) {
          $MAX{AVST_HIL} = $hil_avg;
        }
        if ($hil_avg < $MIN{AVST_HIL}) {
          $MIN{AVST_HIL} = $hil_avg;
        }
      }
      $hol_avg = $hol{AVST} / $sum{AVST};

      if ($hol_avg > 0) {
        if ($hol_avg > $MAX{AVST_HOL}) {
          $MAX{AVST_HOL} = $hol_avg;
        }
        if ($hol_avg < $MIN{AVST_HOL}) {
          $MIN{AVST_HOL} = $hol_avg;
        }
      }
    }
  
    # If we counted some DBUPs, calculate the average GIL, GOL, HIL, HOL
    # and check for MAX/MIN values
    if ($sum{DBUP} != 0) {
      $gil_avg = $gil{DBUP} / $sum{DBUP};

      if ($gil_avg > 0) {
        if ($gil_avg > $MAX{DBUP_GIL}) {
          $MAX{DBUP_GIL} = $gil_avg;
        }
        if ($gil_avg < $MIN{DBUP_GIL}) {
          $MIN{DBUP_GIL} = $gil_avg;
        }
      }
      $gol_avg = $gol{DBUP} / $sum{DBUP};

      if ($gol_avg > 0) {
        if ($gol_avg > $MAX{DBUP_GOL}) {
          $MAX{DBUP_GOL} = $gol_avg;
        }
        if ($gol_avg < $MIN{DBUP_GOL}) {
          $MIN{DBUP_GOL} = $gol_avg;
        }
      }
      $hil_avg = $hil{DBUP} / $sum{DBUP};

      if ($hil_avg > 0) {
        if ($hil_avg > $MAX{DBUP_HIL}) {
          $MAX{DBUP_HIL} = $hil_avg;
        }
        if ($hil_avg < $MIN{DBUP_HIL}) {
          $MIN{DBUP_HIL} = $hil_avg;
        }
      }
      $hol_avg = $hol{DBUP} / $sum{DBUP};

      if ($hol_avg > 0) {
        if ($hol_avg > $MAX{DBUP_HOL}) {
          $MAX{DBUP_HOL} = $hol_avg;
        }
        if ($hol_avg < $MIN{DBUP_HOL}) {
          $MIN{DBUP_HOL} = $hol_avg;
        }
      }
    }
  } # End if Summary
  
  # If we are displaying message rates adjust them prior to 
  # checking for MIN/MAX
  if ($show_rates eq "TRUE") {

    for $msg_type (%sum) {
      $sum{$msg_type} = $sum{$msg_type} / $delta_time;
    }
  }

  # If we are producing a summary report, check for MAX/MIN sum values
  if ($summary_flag eq "TRUE") {

    if ($sum{BOOK} > $MAX{BOOK_SUM}) {
      $MAX{BOOK_SUM} = $sum{BOOK};
    }
    if ($sum{BOOK} < $MIN{BOOK_SUM}) {
      $MIN{BOOK_SUM} = $sum{BOOK};
    }
    if ($sum{PALS} > $MAX{PALS_SUM}) {
      $MAX{PALS_SUM} = $sum{PALS};
    }
    if ($sum{PALS} < $MIN{PALS_SUM}) {
      $MIN{PALS_SUM} = $sum{PALS};
    }
    if ($sum{RPIN} > $MAX{RPIN_SUM}) {
      $MAX{RPIN_SUM} = $sum{RPIN};
    }
    if ($sum{RPIN} < $MIN{RPIN_SUM}) {
      $MIN{RPIN_SUM} = $sum{RPIN};
    }
    if ($sum{AALS} > $MAX{AALS_SUM}) {
      $MAX{AALS_SUM} = $sum{AALS};
    }
    if ($sum{AALS} < $MIN{AALS_SUM}) {
      $MIN{AALS_SUM} = $sum{AALS};
    }
    if ($sum{ERRR} > $MAX{ERRR_SUM}) {
      $MAX{ERRR_SUM} = $sum{ERRR};
    }
    if ($sum{ERRR} < $MIN{ERRR_SUM}) {
      $MIN{ERRR_SUM} = $sum{ERRR};
    }
    if ($sum{AVST} > $MAX{AVST_SUM}) {
      $MAX{AVST_SUM} = $sum{AVST};
    }
    if ($sum{AVST} < $MIN{AVST_SUM}) {
      $MIN{AVST_SUM} = $sum{AVST};
    }
    if ($sum{DBUP} > $MAX{DBUP_SUM}) {
      $MAX{DBUP_SUM} = $sum{DBUP};
    }
    if ($sum{DBUP} < $MIN{DBUP_SUM}) {
      $MIN{DBUP_SUM} = $sum{DBUP};
    }
  }

  # Set prev_time
  $prev_time = $iter_time;
}

##############################
## Subroutine:  dump_stats  ##
##############################
sub dump_stats {
  
  # If lines_per_header was set to 0 or lower never print the header
  if ($lines_per_header > 0) {

    # If we reach the number of lines since the last header, print another one
    if (1 == $num_iters || 0 == ($num_iters % $lines_per_header)) {
      if ($show_rates eq "TRUE") {
        print "  TIME$HDRTPS_FMT\n";
      }
      else {
        print "  TIME$HDRTPM_FMT\n";
      }
    }
  }
  
  # Print the stats
  if ($show_rates eq "TRUE") {

    # Don't include ERRs/AVST in TPS Dwell calc
    $tps = $sum{BOOK} + $sum{PALS} + $sum{RPIN} + $sum{AALS};
    $tps_dwell = ($book_avg * $sum{BOOK}) + ($pals_avg * $sum{PALS}) 
	       + ($rpin_avg * $sum{RPIN}) + ($aals_avg * $sum{AALS});
    if ($tps > 0) {
      $tps_dwell = $tps_dwell / $tps;
    }
    else {
      $tps_dwell = 0;
    }
    $tps = $sum{BOOK} + $sum{PALS} + $sum{RPIN} + $sum{AALS} 
	 + $sum{ERRR} + $sum{AVST};

    # Print message rates
    if ($dwell_type eq "u" || $dwell_type eq "t") {
      printf
        "%s$USWDWELL_FMT $RATESUM_FMT\n",
        $iter_time, $tps_dwell, $book_avg, $pals_avg, $rpin_avg, $aals_avg,
        $tps, $sum{BOOK}, $sum{PALS}, $sum{RPIN}, $sum{AALS}, $sum{ERRR},
        $sum{AVST};

    }
    else {
      printf 
        "%s$ALLDWELL_FMT $RATESUM_FMT\n",
        $iter_time, $tps_dwell, $book_avg, $pals_avg, $rpin_avg, $aals_avg,
        $tps, $sum{BOOK}, $sum{PALS}, $sum{RPIN}, $sum{AALS}, $sum{ERRR},
        $sum{AVST};
      }
  }
  else {

    # Don't include ERRs/AVST in TPS Dwell calc
    $tps = $sum{BOOK} + $sum{PALS} + $sum{RPIN} + $sum{AALS};
    $tps_dwell = $book_avg * $sum{BOOK} + $pals_avg * $sum{PALS} 
               + $rpin_avg * $sum{RPIN} + $aals_avg * $sum{AALS};
    if ($tps > 0) {
      $tps_dwell = $tps_dwell / $tps;
    }
    else {
      $tps_dwell = 0;
    }
    $tps = $sum{BOOK} + $sum{PALS} + $sum{RPIN} 
	 + $sum{AALS} + $sum{ERRR} + $sum{AVST};

    # Print message counts
    if ($dwell_type eq "u" || $dwell_type eq "t") {
      printf
        "%s$USWDWELL_FMT $COUNTSUM_FMT\n",
        $iter_time, $tps_dwell, $book_avg, $pals_avg, $rpin_avg, $aals_avg,
        $tps, $sum{BOOK}, $sum{PALS}, $sum{RPIN}, $sum{AALS}, $sum{ERRR},
        $sum{AVST};
    }
    else {
  
      # Print the statistics
      printf 
        "%s$ALLDWELL_FMT $COUNTSUM_FMT\n",
        $iter_time, $tps_dwell, $book_avg, $pals_avg, $rpin_avg, $aals_avg,
        $tps, $sum{BOOK}, $sum{PALS}, $sum{RPIN}, $sum{AALS}, $sum{ERRR},
        $sum{AVST};
    }
  }

  # Set prev_time
  $prev_time = $iter_time;
}

####################################
## Subroutine:  dump_final_stats  ##
####################################
sub dump_final_stats {
    
  # If we counted some BOOKs, calculate the average response time and lengths
  if ($total_sum{BOOK} != 0) {
    $book_avg = $total_dwell{BOOK} / $total_sum{BOOK};
    $book_gil = $total_gil{BOOK} / $total_sum{BOOK};
    $book_gol = $total_gol{BOOK} / $total_sum{BOOK};
    $book_hil = $total_hil{BOOK} / $total_sum{BOOK};
    $book_hol = $total_hol{BOOK} / $total_sum{BOOK};
  }

  # If we counted some PALS, calculate the average response time and lengths
  if ($total_sum{PALS} != 0) {
    $pals_avg = $total_dwell{PALS} / $total_sum{PALS};
    $pals_gil = $total_gil{PALS} / $total_sum{PALS};
    $pals_gol = $total_gol{PALS} / $total_sum{PALS};
    $pals_hil = $total_hil{PALS} / $total_sum{PALS};
    $pals_hol = $total_hol{PALS} / $total_sum{PALS};
  }

  # If we counted some RPINs, calculate the average response time and lengths
  if ($total_sum{RPIN} != 0) {
    $rpin_avg = $total_dwell{RPIN} / $total_sum{RPIN};
    $rpin_gil = $total_gil{RPIN} / $total_sum{RPIN};
    $rpin_gol = $total_gol{RPIN} / $total_sum{RPIN};
    $rpin_hil = $total_hil{RPIN} / $total_sum{RPIN};
    $rpin_hol = $total_hol{RPIN} / $total_sum{RPIN};
  }

  # If we counted some AALS, calculate the average response time and lengths
  if ($total_sum{AALS} != 0) {
    $aals_avg = $total_dwell{AALS} / $total_sum{AALS};
    $aals_gil = $total_gil{AALS} / $total_sum{AALS};
    $aals_gol = $total_gol{AALS} / $total_sum{AALS};
    $aals_hil = $total_hil{AALS} / $total_sum{AALS};
    $aals_hol = $total_hol{AALS} / $total_sum{AALS};
  }

  # If we counted some ERRRs, calculate the average lengths
  if ($total_sum{ERRR} != 0) {
    $errr_gil = $total_gil{ERRR} / $total_sum{ERRR};
    $errr_gol = $total_gol{ERRR} / $total_sum{ERRR};
    $errr_hil = $total_hil{ERRR} / $total_sum{ERRR};
    $errr_hol = $total_hol{ERRR} / $total_sum{ERRR};
  }

  # If we counted some AVSTs, calculate the average lengths
  if ($total_sum{AVST} != 0) {
    $avst_gil = $total_gil{AVST} / $total_sum{AVST};
    $avst_gol = $total_gol{AVST} / $total_sum{AVST};
    $avst_hil = $total_hil{AVST} / $total_sum{AVST};
    $avst_hol = $total_hol{AVST} / $total_sum{AVST};
  }

  # If we counted some DBUPs, calculate the average lengths
  if ($total_sum{DBUP} != 0) {
    $dbup_gil = $total_gil{DBUP} / $total_sum{DBUP};
    $dbup_gol = $total_gol{DBUP} / $total_sum{DBUP};
    $dbup_hil = $total_hil{DBUP} / $total_sum{DBUP};
    $dbup_hol = $total_hol{DBUP} / $total_sum{DBUP};
  }

  # Change MIN defaults from MIN_DEF to 0
  for $msg_type (%MIN) {
    if ($MIN_DEF == $MIN{$msg_type}) {
      $MIN{$msg_type} = 0;
    }
  }

  # If the number of iterations is greater than 0 
  if ($num_iters > 0) {
    for $msg_type (%total_sum) {
        $total_sum{$msg_type} = $total_sum{$msg_type} / $num_iters;
    }
  }

  # Print the header
  print "Data from $month/$day $first_time to $month/$day $last_time\n";
  if ($show_rates eq "TRUE") {
    print "  $HDRTPS_FMT\n";
  }
  else {
    print "  $HDRTPM_FMT\n";
  }
  
  if ($show_rates eq "TRUE") {

    # If we are displaying message rates adjust them prior to displaying
    for $msg_type (%total_sum) {
      $total_sum{$msg_type} = $total_sum{$msg_type} / $delta_time;
    }
  }

    # Don't include ERRs/AVST in TPS Dwell calc
    $tps = $total_sum{BOOK} + $total_sum{PALS} 
	 + $total_sum{RPIN} + $total_sum{AALS};
    $tps_dwell = ($book_avg * $total_sum{BOOK}) 
	       + ($pals_avg * $total_sum{PALS}) 
	       + ($rpin_avg * $total_sum{RPIN}) 
	       + ($aals_avg * $total_sum{AALS});
    if ($tps > 0) {
      $tps_dwell = $tps_dwell / $tps;
    }
    else {
      $tps_dwell = 0;
    }
    $tps_dwell = $tps_dwell / $tps;
    $tps = $total_sum{BOOK} + $total_sum{PALS} 
	 + $total_sum{RPIN} + $total_sum{AALS} 
	 + $total_sum{ERRR} + $total_sum{AVST};

    $maxtps = $MAX{BOOK_SUM} + $MAX{PALS_SUM} 
	    + $MAX{RPIN_SUM} + $MAX{AALS_SUM};
    $maxtps_dwell = ($MAX{BOOK_DWELL} * $MAX{BOOK_SUM}) 
                  + ($MAX{PALS_DWELL} * $MAX{PALS_SUM})
                  + ($MAX{RPIN_DWELL} * $MAX{RPIN_SUM})
                  + ($MAX{AALS_DWELL} * $MAX{AALS_SUM});
    if ($maxtps > 0) {
      $maxtps_dwell = $maxtps_dwell / $maxtps;
    }
    else {
      $maxtps_dwell = 0;
    }
    $maxtps = $MAX{BOOK_SUM} + $MAX{PALS_SUM} 
	    + $MAX{RPIN_SUM} + $MAX{AALS_SUM} 
	    + $MAX{ERRR_SUM} + $MAX{AVST_SUM};

    $mintps = $MIN{BOOK_SUM} + $MIN{PALS_SUM} 
	    + $MIN{RPIN_SUM} + $MIN{AALS_SUM};
    $mintps_dwell = ($MIN{BOOK_DWELL} * $MIN{BOOK_SUM}) 
                  + ($MIN{PALS_DWELL} * $MIN{PALS_SUM}) 
		  + ($MIN{RPIN_DWELL} * $MIN{RPIN_SUM}) 
		  + ($MIN{AALS_DWELL} * $MIN{AALS_SUM});
    if ($mintps > 0) {
      $mintps_dwell = $mintps_dwell / $mintps;
    }
    else {
      $mintps_dwell = 0;
    }
    $mintps = $MIN{BOOK_SUM} + $MIN{PALS_SUM} 
	    + $MIN{RPIN_SUM} + $MIN{AALS_SUM} 
	    + $MIN{ERRR_SUM} + $MIN{AVST_SUM};
  
  if ($show_rates eq "TRUE") {
    if ($dwell_type eq "u" || $dwell_type eq "t") {
      printf
        "AVG:$USWDWELL_FMT $RATESUM_FMT\n",
        $tps_dwell, $book_avg, $pals_avg, $rpin_avg, $aals_avg,
        $tps, $total_sum{BOOK}, $total_sum{PALS}, $total_sum{RPIN}, 
	$total_sum{AALS}, $total_sum{ERRR}, $total_sum{AVST};
      printf 
        "MAX:$USWDWELL_FMT $RATESUM_FMT\n",
        $maxtps_dwell, $MAX{BOOK_DWELL}, $MAX{PALS_DWELL}, 
	$MAX{RPIN_DWELL}, $MAX{AALS_DWELL},
        $maxtps, $MAX{BOOK_SUM}, $MAX{PALS_SUM}, $MAX{RPIN_SUM},
	$MAX{AALS_SUM}, $MAX{ERRR_SUM}, $MAX{AVST_SUM};
      printf 
        "MIN:$USWDWELL_FMT $RATESUM_FMT\n",
        $mintps_dwell, $MIN{BOOK_DWELL}, $MIN{PALS_DWELL}, 
	$MIN{RPIN_DWELL}, $MIN{AALS_DWELL},
        $mintps, $MIN{BOOK_SUM}, $MIN{PALS_SUM}, $MIN{RPIN_SUM},
	$MIN{AALS_SUM}, $MIN{ERRR_SUM}, $MIN{AVST_SUM};
      }
    else {
      printf
        "AVG:$ALLDWELL_FMT $RATESUM_FMT\n",
        $tps_dwell, $book_avg, $pals_avg, $rpin_avg, $aals_avg,
        $tps, $total_sum{BOOK}, $total_sum{PALS}, $total_sum{RPIN}, 
	$total_sum{AALS}, $total_sum{ERRR}, $total_sum{AVST};
      printf 
        "MAX:$ALLDWELL_FMT $RATESUM_FMT\n",
        $maxtps_dwell, $MAX{BOOK_DWELL}, $MAX{PALS_DWELL}, 
	$MAX{RPIN_DWELL}, $MAX{AALS_DWELL},
        $maxtps, $MAX{BOOK_SUM}, $MAX{PALS_SUM}, $MAX{RPIN_SUM},
	$MAX{AALS_SUM}, $MAX{ERRR_SUM}, $MAX{AVST_SUM};
      printf 
        "MIN:$ALLDWELL_FMT $RATESUM_FMT\n",
        $mintps_dwell, $MIN{BOOK_DWELL}, $MIN{PALS_DWELL}, 
	$MIN{RPIN_DWELL}, $MIN{AALS_DWELL},
        $mintps, $MIN{BOOK_SUM}, $MIN{PALS_SUM}, $MIN{RPIN_SUM},
	$MIN{AALS_SUM}, $MIN{ERRR_SUM}, $MIN{AVST_SUM};
    }
  }
  else {
    if ($dwell_type eq "u" || $dwell_type eq "t") {
      printf
        "AVG:$USWDWELL_FMT $COUNTSUM_FMT\n",
        $tps_dwell, $book_avg, $pals_avg, $rpin_avg, $aals_avg,
        $tps, $total_sum{BOOK}, $total_sum{PALS}, $total_sum{RPIN}, 
	$total_sum{AALS}, $total_sum{ERRR}, $total_sum{AVST};
      printf 
        "MAX:$USWDWELL_FMT $COUNTSUM_FMT\n",
        $maxtps_dwell, $MAX{BOOK_DWELL}, $MAX{PALS_DWELL}, 
	$MAX{RPIN_DWELL}, $MAX{AALS_DWELL},
        $maxtps, $MAX{BOOK_SUM}, $MAX{PALS_SUM}, $MAX{RPIN_SUM},
	$MAX{AALS_SUM}, $MAX{ERRR_SUM}, $MAX{AVST_SUM};
      printf 
        "MIN:$USWDWELL_FMT $COUNTSUM_FMT\n",
        $mintps_dwell, $MIN{BOOK_DWELL}, $MIN{PALS_DWELL}, 
	$MIN{RPIN_DWELL} ,$MIN{AALS_DWELL},
        $mintps, $MIN{BOOK_SUM}, $MIN{PALS_SUM}, $MIN{RPIN_SUM},
	$MIN{AALS_SUM}, $MIN{ERRR_SUM}, $MIN{AVST_SUM};
    }
    else {
      printf 
        "AVG:$ALLDWELL_FMT $COUNTSUM_FMT\n",
        $tps_dwell, $book_avg, $pals_avg, $rpin_avg, $aals_avg,
        $tps, $total_sum{BOOK}, $total_sum{PALS}, $total_sum{RPIN}, 
	$total_sum{AALS}, $total_sum{ERRR}, $total_sum{AVST};
      printf 
        "MAX:$ALLDWELL_FMT $COUNTSUM_FMT\n",
        $maxtps_dwell, $MAX{BOOK_DWELL}, $MAX{PALS_DWELL}, 
	$MAX{RPIN_DWELL}, $MAX{AALS_DWELL},
        $maxtps, $MAX{BOOK_SUM}, $MAX{PALS_SUM}, $MAX{RPIN_SUM},
	$MAX{AALS_SUM}, $MAX{ERRR_SUM}, $MAX{AVST_SUM};
      printf 
        "MIN:$ALLDWELL_FMT $COUNTSUM_FMT\n",
        $mintps_dwell, $MIN{BOOK_DWELL}, $MIN{PALS_DWELL}, 
	$MIN{RPIN_DWELL}, $MIN{AALS_DWELL},
        $mintps, $MIN{BOOK_SUM}, $MIN{PALS_SUM}, $MIN{RPIN_SUM},
	$MIN{AALS_SUM}, $MIN{ERRR_SUM}, $MIN{AVST_SUM};
    }
  }

  # Display the message lengths
      printf "\n$LENHDR_FMT\n";
      printf 
        "AVG: GIL $LENGTH_FMT\n",
        $book_gil, $pals_gil, $rpin_gil, $aals_gil, $errr_gil, $avst_gil;
      printf 
        "     GOL $LENGTH_FMT\n",
        $book_gol, $pals_gol, $rpin_gol, $aals_gol, $errr_gol, $avst_gol;
      printf 
        "     HIL $LENGTH_FMT\n",
        $book_hil, $pals_hil, $rpin_hil, $aals_hil, $errr_hil, $avst_hil;
      printf 
        "     HOL $LENGTH_FMT\n",
        $book_hol, $pals_hol, $rpin_hol, $aals_hol, $errr_hol, $avst_hol;
      printf 
        "MAX: GIL $LENGTH_FMT\n",
        $MAX{BOOK_GIL}, $MAX{PALS_GIL}, $MAX{RPIN_GIL}, $MAX{AALS_GIL},
	$MAX{ERRR_GIL}, $MAX{AVST_GIL};
      printf 
        "     GOL $LENGTH_FMT\n",
        $MAX{BOOK_GOL}, $MAX{PALS_GOL}, $MAX{RPIN_GOL}, $MAX{AALS_GOL},
	$MAX{ERRR_GOL}, $MAX{AVST_GOL};
      printf 
        "     HIL $LENGTH_FMT\n",
        $MAX{BOOK_HIL}, $MAX{PALS_HIL}, $MAX{RPIN_HIL}, $MAX{AALS_HIL},
	$MAX{ERRR_HIL}, $MAX{AVST_HIL};
      printf 
        "     HOL $LENGTH_FMT\n",
        $MAX{BOOK_HOL}, $MAX{PALS_HOL}, $MAX{RPIN_HOL}, $MAX{AALS_HOL},
	$MAX{ERRR_HOL}, $MAX{AVST_HOL};
      printf 
        "MIN: GIL $LENGTH_FMT\n",
        $MIN{BOOK_GIL}, $MIN{PALS_GIL}, $MIN{RPIN_GIL}, $MIN{AALS_GIL},
	$MIN{ERRR_GIL}, $MIN{AVST_GIL};
      printf 
        "     GOL $LENGTH_FMT\n",
        $MIN{BOOK_GOL}, $MIN{PALS_GOL}, $MIN{RPIN_GOL}, $MIN{AALS_GOL},
	$MIN{ERRR_GOL}, $MIN{AVST_GOL};
      printf 
        "     HIL $LENGTH_FMT\n",
        $MIN{BOOK_HIL}, $MIN{PALS_HIL}, $MIN{RPIN_HIL}, $MIN{AALS_HIL},
	$MIN{ERRR_HIL}, $MIN{AVST_HIL};
      printf 
        "     HOL $LENGTH_FMT\n",
        $MIN{BOOK_HOL}, $MIN{PALS_HOL}, $MIN{RPIN_HOL}, $MIN{AALS_HOL},
	$MIN{ERRR_HOL}, $MIN{AVST_HOL};
}

###############################
##  Subroutine:  init_stats  ##
###############################
sub init_stats {

  $zone = `uname -n`;
  chomp($zone);

  # Set Month / Day just in case it isn't entered on the command line
  ($sec, $min, $hour, $day, $month, $year, $week, $julian, $isdst)=gmtime(time);
  $year -= 100;
  $month++;

  # Using the LOGNAME env variable determine which TPE we are on.
  if ($ENV{LOGNAME} =~ /^usw$|^prod_sup$/) {
    $statdir = "/$zone/logs/stats";  
    $delta_time = 60;
  }
  elsif ($ENV{LOGNAME} eq "qa" or $ENV{LOGNAME} eq "uat") {
    $statdir = "/$zone/logs/stats";
    $delta_time = 10;
  }
  elsif ($ENV{LOGNAME} eq "qa2") {
    $statdir = "/qa2/stats";
    $delta_time = 10;
  }
  elsif ($ENV{LOGNAME} eq "uswrpt") {
    $filemonth = sprintf "%02d%d", $month, $year;
    $statdir = "/$zone/loghist/uswprod01/stats/$filemonth";
    $delta_time = 60;
  }
  else {
#$statdir = "/pegs/logcabin02/uswprod01/uswprod01/logs/stats";
    $statdir = "/research/sand/mwatson/stats";
    $delta_time = 60;
  }
  
  # Default some variables
  $lines_per_header = "20";
  $tail_limit = 100000;
  $first_time = "TRUE";
  $num_iters = 0;
  $exit_flag = "FALSE";

  # Default command line variables
  $show_rates = "FALSE";
  $summary_flag = "FALSE";
  $tail_file = "FALSE";
  $dwell_type = "u";
  $flag_hrs = "OFF";
  $flag_gds = "OFF";
  $flag_trq = "OFF";
  $flag_trp = "OFF";
  $filter_hrs = "NONE";
  $filter_gds = "NONE";
  $filter_trq = "NONE";
  $filter_trp = "NONE";


  # Default summary variables
  %sum = ();
  %dwell = ();
  %gil = ();
  %gol = ();
  %hil = ();
  %hol = ();
  %total_dwell = ();
  %total_sum = ();
  %total_gil = ();
  %total_gol = ();
  %total_hil = ();
  %total_hol = ();
  %MAX = ();
  %MIN = ();
  $MIN_DEF = 9999999;
  $MAX{BOOK_DWELL} = 0;
  $MAX{PALS_DWELL} = 0;
  $MAX{RPIN_DWELL} = 0;
  $MAX{AALS_DWELL} = 0;
  $MAX{BOOK_SUM} = 0;
  $MAX{PALS_SUM} = 0;
  $MAX{RPIN_SUM} = 0;
  $MAX{AALS_SUM} = 0;
  $MAX{ERRR_SUM} = 0;
  $MAX{AVST_SUM} = 0;
  $MAX{DBUP_SUM} = 0;

  $MAX{BOOK_GIL} = 0;
  $MAX{PALS_GIL} = 0;
  $MAX{RPIN_GIL} = 0;
  $MAX{AALS_GIL} = 0;
  $MAX{ERRR_GIL} = 0;
  $MAX{AVST_GIL} = 0;
  $MAX{DBUP_GIL} = 0;
  $MAX{BOOK_GOL} = 0;
  $MAX{PALS_GOL} = 0;
  $MAX{RPIN_GOL} = 0;
  $MAX{AALS_GOL} = 0;
  $MAX{ERRR_GOL} = 0;
  $MAX{AVST_GOL} = 0;
  $MAX{DBUP_GOL} = 0;
  $MAX{BOOK_HIL} = 0;
  $MAX{PALS_HIL} = 0;
  $MAX{RPIN_HIL} = 0;
  $MAX{AALS_HIL} = 0;
  $MAX{ERRR_HIL} = 0;
  $MAX{AVST_HIL} = 0;
  $MAX{DBUP_HOL} = 0;
  $MAX{BOOK_HOL} = 0;
  $MAX{PALS_HOL} = 0;
  $MAX{RPIN_HOL} = 0;
  $MAX{AALS_HOL} = 0;
  $MAX{ERRR_HOL} = 0;
  $MAX{AVST_HOL} = 0;
  $MAX{DBUP_HOL} = 0;

  $MIN{BOOK_DWELL} = $MIN_DEF;
  $MIN{PALS_DWELL} = $MIN_DEF;
  $MIN{RPIN_DWELL} = $MIN_DEF;
  $MIN{AALS_DWELL} = $MIN_DEF;
  $MIN{BOOK_SUM} = $MIN_DEF;
  $MIN{PALS_SUM} = $MIN_DEF;
  $MIN{RPIN_SUM} = $MIN_DEF;
  $MIN{AALS_SUM} = $MIN_DEF;
  $MIN{ERRR_SUM} = $MIN_DEF;
  $MIN{AVST_SUM} = $MIN_DEF;
  $MIN{DBUP_SUM} = $MIN_DEF;

  $MIN{BOOK_GIL} = $MIN_DEF;
  $MIN{PALS_GIL} = $MIN_DEF;
  $MIN{RPIN_GIL} = $MIN_DEF;
  $MIN{AALS_GIL} = $MIN_DEF;
  $MIN{ERRR_GIL} = $MIN_DEF;
  $MIN{AVST_GIL} = $MIN_DEF;
  $MIN{DBUP_GIL} = $MIN_DEF;
  $MIN{BOOK_GOL} = $MIN_DEF;
  $MIN{PALS_GOL} = $MIN_DEF;
  $MIN{RPIN_GOL} = $MIN_DEF;
  $MIN{AALS_GOL} = $MIN_DEF;
  $MIN{ERRR_GOL} = $MIN_DEF;
  $MIN{AVST_GOL} = $MIN_DEF;
  $MIN{DBUP_GOL} = $MIN_DEF;
  $MIN{BOOK_HIL} = $MIN_DEF;
  $MIN{PALS_HIL} = $MIN_DEF;
  $MIN{RPIN_HIL} = $MIN_DEF;
  $MIN{AALS_HIL} = $MIN_DEF;
  $MIN{ERRR_HIL} = $MIN_DEF;
  $MIN{AVST_HIL} = $MIN_DEF;
  $MIN{DBUP_HOL} = $MIN_DEF;
  $MIN{BOOK_HOL} = $MIN_DEF;
  $MIN{PALS_HOL} = $MIN_DEF;
  $MIN{RPIN_HOL} = $MIN_DEF;
  $MIN{AALS_HOL} = $MIN_DEF;
  $MIN{ERRR_HOL} = $MIN_DEF;
  $MIN{AVST_HOL} = $MIN_DEF;
  $MIN{DBUP_HOL} = $MIN_DEF;


  # Use variables for the formating of the output lines
  $USWDWELL_FMT = "%6.3f%6.3f%6.3f%6.3f%6.3f";
  $ALLDWELL_FMT = "%6.2f%6.2f%6.2f%6.2f%6.2f";
  $RATESUM_FMT =  "%6.1f%5.1f %5.1f %5.1f %5.1f %5.1f%5.1f";
  $COUNTSUM_FMT = "%6.0f%5.0f %5.0f %5.0f %5.0f %5.0f%5.0f";
  $LENGTH_FMT =   "%5.0f %5.0f %5.0f %5.0f %5.0f %5.0f %5.0f";
  $LENHDR_FMT = "          BOOK  PALS  RPIN  AALS  ERRR  AVST";
  $HDRTPS_FMT = "   TPS  BOOK  PALS  RPIN  AALS  ERRR AVST";
  $HDRTPS_FMT = "     TPS  BOOK  PALS  RPIN  AALS$HDRTPS_FMT";
  $HDRTPM_FMT = "   TPM  BOOK  PALS  RPIN  AALS  ERRR AVST";
  $HDRTPM_FMT = "     TPM  BOOK  PALS  RPIN  AALS$HDRTPM_FMT";
}


################################
##  Subroutine:  clear_stats  ##
################################
sub clear_stats {

  # Clear the iterative bit buckets
  %sum = ();
  %dwell = ();
  %gil = ();
  %gol = ();
  %hil = ();
  %hol = ();
  $book_avg = 0;
  $pals_avg = 0;
  $rpin_avg = 0;
  $aals_avg = 0;
}

#################################
##  Subroutine: parse_cmdline  ##
#################################
sub parse_cmdline {

  GetOptions (
    'h=s' => \$local_hrs,
    'g=s' => \$local_gds,
    's' => \$local_summary,
    'l=i' => \$lines_per_header,
    'd=s' => \$local_dwell,
    'r' => \$local_rates,
    'U=s' => \$local_tlimit,
    't' => \$local_tail,
    'help' => \$help,
    'trq=i' => \$local_trq,
    'trp=i' => \$local_trp
  );

  # If we haven't already tturned on the HRS filter, do so now 
  if ($local_hrs) {
    $flag_hrs = "ON";
    $filter_hrs = $local_hrs;
  }

  if ($local_dwell) {
    # If we have a valid dwell_type replace it
    if ($local_dwell eq "g" || $local_dwell eq "h" || $local_dwell eq "t") {
      $dwell_type = $local_dwell;
    }
  }
  
  # If the gds_filter has not ben previously set
  if ($local_gds) {
    $flag_gds = "ON";
    $filter_gds = $local_gds;
  }

  # If the trq_filter has not ben previously set
  if ($local_trq) {
    $flag_trq = "ON";
    $filter_trq = $local_trq;
  }

  # If the trp_filter has not ben previously set
  if ($local_trp) {
    $flag_trp = "ON";
    $filter_trp = $local_trp;
  }

  # Set tail limit or unlimited
  if ($local_tlimit) {
    $tail_limit = $local_tlimit;
  }

  # If we match a MM/DD format use it as the date.
  if ($ARGV[0] && $ARGV[0] =~ /(\d+)\/(\d+)/) {
    
    # Set day and month variables
    $month = $1;
    $day = $2;
  }

  if ($help) {

    print STDERR "Usage:\n";
    print STDERR "  MM/DD = Date of Stats file to parse\n";
    print STDERR "  -r = Display message rates [Default counts]\n";
    print STDERR "  -q = Don't display header messages\n";
    print STDERR "  -d [uhgt] = Dwell times: usw,hrs,gds,tpp [Default usw]\n";
    print STDERR "  -h hrs = HRS Filter (-h HI or -h \"HI|IC\")\n";
    print STDERR "  -g gds = GDS Filter (-g WB or -g \"WB|HD\")\n";
    print STDERR "  -s = Display summary report (AVG, MAX, MIN)\n";
    print STDERR "  -trq = Request TPE Filter (-trq 1)\n";
    print STDERR "  -trp = Response TPE Filter (-trp 1)\n";
    exit;
  }

  if ($flag_hrs eq "ON") {
    print STDERR "HRS Filter: $filter_hrs\n";
  }
  if ($flag_gds eq "ON") {
    print STDERR "GDS Filter: $filter_gds\n";
  }
  if ($flag_trq eq "ON") {
    print STDERR "Request TPE Filter: $filter_trq\n";
  }
  if ($flag_trp eq "ON") {
    print STDERR "Response TPE Filter: $filter_trp\n";
  }
  if ($local_tail) {
    $tail_file = "TRUE";
    print STDERR "Displaying tail information\n";
  }
  if ($local_summary) {
    $summary_flag = "TRUE";
    print STDERR "Displaying summary information\n";
  }
  if ($local_rates) {
    $show_rates = "TRUE";
    print STDERR "Displaying message rates\n";
  }
  else {
    print STDERR "Displaying message counts\n";
  }
  if ($dwell_type eq "g") {
    print STDERR "Displaying GDS dwell times\n";
  }
  elsif ($dwell_type eq "h") {
    print STDERR "Displaying HRS dwell times\n";
  }
  elsif ($dwell_type eq "t") {
    print STDERR "Displaying TPP dwell times\n";
  }
  else {
    print STDERR "Displaying USW dwell times\n";
  }

  # Make sure that the user doesn't ask for a summary of tail information
  if ($summary_flag eq "TRUE" && $tail_file eq "TRUE") {
    print STDERR "\nThe summary report and tail are mutually exclusive\n";
    print STDERR "You need to remove the -s or run stless\n";
    exit;
  }
}

####################################
##  Subroutine:  open_stats_file  ##
####################################
sub open_stats_file {

  # Build the statfile variable
  $filedate = sprintf "%02d%02d", $month, $day;
  $statfile = sprintf "%s/result%s.log", $statdir, $filedate;

  # Check to see if the statfile exists
  if (! -e $statfile) {
    print STDERR "Error opening $statfile\n";
    exit;
  }
  print STDERR "Processing: $statfile\n";
  
  # If tail_file is true open a tail pipe 
  if ($tail_file eq "TRUE") {
    open FIL, "/bin/tail -f $statfile |" or die "Can't tail $statfile.\n";
  }
  else {
    if ($tail_limit eq "A" || $tail_limit eq "All" ||
	$tail_limit eq "ALL" ||  $tail_limit eq "all"){
      open FIL, "/bin/cat $statfile |" or
           die "Can't open $statfile for reading.\n";
    }
    else {
      open FIL, "/bin/tail -$tail_limit $statfile |" or
           die "Can't open $statfile for reading.\n";
    }
  }
}
