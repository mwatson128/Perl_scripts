#!/usr/local/bin/perl
# (]$[) check_kiva.pl:1.1 | CDATE=04/08/02 10:58:01
# Find rogue Kivanet processes

# Array of non-Kivanet proceses
@ignore_list = 
(
  "rlogin", "telnet", "ksh", "csh", "sh", "perl", "top" 
);

# Get username
$id = `/usr/bin/id`;
$id =~ /^uid=.*\((.*)\) gid/;
$username = $1;

# Get a list of the processes in use
@psout = ` ps -eo "pid, user, comm"`;

# Pop off the header row
shift @psout;

# Cycle through the process and determine if process is from Kivanet
for $proc (@psout) {
  chomp $proc;
  @proc = split / +/, $proc;

  # Make sure that first element is the PID of the process
  if ($proc[0] !~ /\d+/) {
    shift @proc;
  }

  #  Make sure that the process is owned by the user running it
  if ($proc[1] eq $username) {
    
    # Assume that the proess is a Kivanet process
    $ok = "FALSE";
   
    # Compare the process name with the ignore list
    for $ignore (@ignore_list) {
      
      # If you find a match set ok to TRUE
      if ($proc[2] =~ /$ignore/) {
        $ok = "TRUE";
      }
    }

    # If ok is FALSE its a Kivanet process so print it
    if ($ok eq "FALSE") {
      printf "Found a rogue: %s %s\n", $proc[0], $proc[2];
    }
  }
}
