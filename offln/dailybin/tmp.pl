##
##SUBTTL set_connection_up 
##                                                        
## Set a connection up
##                                                        
## Parameters:                                             
##    None
##
## Returns:                                             
##    None
##
## Globals:
##    None
##
## Locals:
##    None
##

sub set_connection_up {

  DBUG_ENTER("set_connection_up");

  # Grab variables from function arguments
  my ($ip, $time_up, $reason) = @_;

  DBUG_PRINT("set_connection_up", "Uping %s at %s reason: %s", 
       $ip, $time_up, $reason);

  # Get uptime of last outage
  ($old_down, $old_up) = split /\|/, $curr_outages{$ip};

  # If we have a downtime process normally
  if ($currently_down{$ip} ne "") {
  
    # Split downtime and reason
    ($curr_down, $reason_down) = split /\|/, $currently_down{$ip};
    
    # If the last up time is within the downtime, update last outage with 
    # new up time
    if (calc_time_diff($old_up, $curr_down) < 5) {
      $curr_outages{$ip} = sprintf "%s|%s", $old_down, $time_up;
      DBUG_PRINT("set_connection_up", "%s already down: %s up: %s new_up %s\n",
                    $ip, $old_down, $old_up, $time_up);
    }
    else {

      if (($reason eq "IP") || ($reason eq $reason_down)) {
      
        # If the outage hash has data for the IP, load that outage into the
        # outage array
        if ($curr_outages{$ip} ne "") {
        
          push @outages, sprintf "%s|%s|%s", 
               $old_down, $old_up, $ip;
          DBUG_PRINT("set_connection_up", "%s added to ARRAY down: %s up: %s", 
                     $ip, $old_down, $old_up);
        }
        DBUG_PRINT("set_connection_up", "%s added to HASH down: %s up: %s", 
                   $ip, $curr_down, $time_up);

        # Load outage times into outage hash
        $curr_outages{$ip} = sprintf "%s|%s", 
           $curr_down, $time_up;

        # Remove downtime from currently_down hash
        $currently_down{$ip} = "";
      }
    }
  } 

  # If we don't have a downtime handle with care
  else {
    
    # If we already reported this IP up, dump an error message 
    if ($last_up{$ip} ne "") {
      printf STDERR "%s has no downtime and was already reported up at %s\n", 
           $ip, $last_up{$ip};
    }  
    
    # Set downtime to top of the day (00:00:00), update the outages array,
    # as well as the last_up hash
    else {

      # Update outages hash
      $curr_outages{$ip} = sprintf "%s|%s",
           "00:00:00", $time_up;
      DBUG_PRINT("set_connection_up", "%s added to HASH down: %s up: %s", 
                 $ip, "00:00:00",  $time_up);
    }
  }

  # Update last_up 
  $last_up{$ip} = $time_up;

  DBUG_VOID_RETURN();
}
