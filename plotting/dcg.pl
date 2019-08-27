#!/usr/local/bin/perl
use Time::Local;
use POSIX;
$|=1;

## Initialize a few variables
$ENV{'TZ'}     = "GMT";
$env           = "UD";
$user          = "kdaniel";
$remotehost    = "sysmon";
$perl          = "/usr/local/bin/perl";
$base          = "/capacity";
$removedupes   = "$base/bin/remove_dupes.pl";
$gnuplot       = "$base/bin/gnuplot-4.2.4";
$ps2jpg        = "$base/bin/ps2jpg";
$jpegtran      = "$base/bin/jpegtran";
$path          = "$base/$env/DC";
$Tspackle      = "$ENV{'HOME'}/bin/time-spackle";
$RELOAD        = "$path/RELOAD-g";
$DEBUG         = "$path/DEBUG-g";
$debugout      = "$path/debug.g";
$fins_smoother = "$path/fins/fins_smoother";
$fins_peak     = "$path/fins/fins_peak";
$asadmin       = "$path/DCasadmin.pl";
$tmp           = "$path/tmp";
$remote_path   = "/web/docs/$env/DC";
$peak_window   = 120;
$timeout       = 15;
$wait          = 30;
$peak_error    = 40;
$peak_warn     = 20;
$DO_DEBUG_LOG  = 0;
$previous_year  = "";
$previous_month = "";
$previous_day   = "";
$previous_hour  = "";
$this_script   = $0;

## Instantiate a lib of shared subroutines
require "$path/DClib.pl";

## Copy this script to a dot file so we can keep track of what is running
$this_script =~ /(.+)\/(.+)\.pl/;
$running = "$1/\.$2\.running";
system("cp $this_script $running");

## Gnuplot-specific variables
$yRange = 60;
$xRange = 1800;
@labels;

## Graph Line Type (re-order color precedence)
my %lt = ("0" => "1",
          "1" => "2",
          "2" => "4",
          "3" => "3",
          "4" => "8",
          "5" => "9");
$ltcnt = scalar(keys(%lt));

## Force an initial load of the configuration file(s)
system("touch $RELOAD");
if ($?) { die "Could not create reload file $RELOAD!\n"; }

## Main Loop - Repeat Forever
while(1) {

  ## Get new time/date values
  $previous_year = $YYYY;
  $previous_month = $MM;
  $hh   = strftime("%H", gmtime);
  $MM   = strftime("%m", gmtime);
  $DD   = strftime("%d", gmtime);
  $YYYY = strftime("%Y", gmtime);

  ## Check for the debug file and start logging if it is found
  if (-e $DEBUG) {
    $DO_DEBUG_LOG = 1;
    open (LOG, ">>$debugout");
    $currentFH = select LOG;
    $|=1;
    select $currentFH;
  }

  ## Start the timer
  $start = time;
  if ($DO_DEBUG_LOG) { print LOG "===== ($start) $YYYY-$MM-$DD =====\n"; }

  ## Reset our date-specific variables
  $archive  = "$path/archive/$YYYY/$MM";

  ## Check for the "reload config cache" file
  if (-e $RELOAD) {
    &ReadConfigs;

    ## Get thread counts from each server and store the results
    &PollThreads;
  }

  ## Do this once per hour:
  if ($hh ne $previous_hour) {
    $previous_hour = $hh;
  }

  ## Do this once per day (30 minutes after rollover):
  if ($DD ne $previous_day) {
    if (strftime("%M", gmtime(time)) eq "30") {
      ## Force a re-load of the configuration files
      system("touch $RELOAD");

      ## Do log cleanup on the previous day's files
      if ($previous_month && $previous_year) {
        $oldlogs = "$path/archive/$previous_year/$previous_month";
        $cmd = "/bin/gzip $oldlogs/$previous_year$previous_month$previous_day-*.txt 2>>$debugout";
        if ($DO_DEBUG_LOG) { print LOG " - '$cmd'\n"; }
        system($cmd);
      }

      $previous_day = $DD;
    }
  }

  ## Now process all the files
  &SmoothRealTime;

  ## Stop the timer
  $end = time;

  ## Sleep based on the diff between wait time and duration
  $diff = ($wait - ($end - $start));
  $nap = ($diff > 0 ? $diff : 1);
  if ($DO_DEBUG_LOG) { print LOG "===== ($end) sleep:$nap =====\n"; }
  sleep($nap);

  ## Check to see if the debugging is still "on"
  if (-e $DEBUG) {
    ## Still active; do nothing
  } else {
    ## Reset the debug flag back to zero and close the file
    $DO_DEBUG_LOG = 0;
    close(LOG);
  }

} #end while loop
exit;


##########################################################
## Call an external script to poll the servers and get  ##
## thread counts for use in the duty cycle calculation. ##
##########################################################
sub PollThreads {
  undef(%threads);

  ## Poll the AS9.x servers to get thread counts
  chomp(@threadcounts = `$asadmin threads`);
  foreach $line (@threadcounts) {
    if ($line =~ /^THREADS:([^:]+):([0-9]+)/) {
      $instances{$1} = 1;
      $threads{$1} = $2;
    }
  }

  ## Determine the thread counts for each host
  foreach $HOST (sort(@hosts)) {
    foreach $tmpinst (split(/,/, $hostinstances{$HOST})) {
      $threads{$HOST} += $threads{$tmpinst};
    }
  }

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Done.\n"; }

  ## Debug - print the thread details
  if ($DO_DEBUG_LOG) { foreach $entity (sort(keys(%threads))) { print LOG "$entity : $threads{$entity} threads.\n"; } }

} #end sub PollThreads


############################################################
## Now fork a new child process for each DAS in our list, ##
## processing each instance in that DAS, smoothing the    ##
## values using fish (thread count and timeout values are ##
## passed in to fish as additional arguments), and then   ##
## store the results into tmp files (used by gnuplot).    ##
############################################################
sub SmoothRealTime {

  foreach $HOST (@hosts) {

    ## Fork a child process for each entity
    if ($kidpid{$HOST} = fork) {
  
      ## Parent process - do nothing
      if ($DO_DEBUG_LOG) { print LOG "Forked pid $kidpid{$HOST} for $HOST\n"; }
  
    } elsif (defined($kidpid{$HOST})) {
      ## Child process - do the work here

      ## Get the instances for this host
      undef(@insts);
      my $hostmax = 0;
      my @insts = sort(split(/,/,$hostinstances{$HOST}));

      ## Loop through each instance on this host
      foreach $instance (@insts) {
        $todayfile     = "$archive/$YYYY$MM$DD-$instance.txt";
        $yesterdayfile = "";
        $prepared = "$tmp/$instance-prepared.txt";
        $smoothed = "$tmp/$instance-smoothed.txt";
        $instancelist .= " $prepared";

        ## Debug - print current status/results
        if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Smoothing archive file for $instance...\n"; }

        ## Sample log line
        ## 2008-11-10 16:38:51|d2c3_instance_8|25404|41|

        ## Find the most recent timestamp of the file (hour & minute)
        my $etime = substr(`tail -1 $todayfile`, 11, 5);
        $e_mn = substr($etime,3,2);
        $e_hr = substr($etime,0,2);
        if ($etime) { $end_time = timegm(0,$e_mn,$e_hr,$DD,$MM-1,$YYYY-1900); }
        $start_time = $end_time - $xRange;
        $s_hr = strftime("%H", gmtime($start_time));
        $s_mn = strftime("%M", gmtime($start_time));
        $dd    = strftime("%d", gmtime($start_time));

        ## Determine if we need to use yesterday's data along with today's
        if ($dd ne $DD) {
          ## Figure out yesterday's file name
          $yyyy = strftime("%Y", gmtime($start_time));
          $mm   = strftime("%m", gmtime($start_time));
          $yesterdayfile = "$path/archive/$yyyy/$mm/$yyyy$mm$dd-$instance.txt";
        } else {
          $yyyy = $YYYY;
          $mm   = $MM;
        }
        $search = "$yyyy-$mm-$dd $s_hr:$s_mn";

        ## Get only the last 'xRange' lines & put them in the 'prepared'
        ## file (some of the lines may come from yesterday's file).
        $cmd  = "hunter clock time '$search' for 30 minutes $yesterdayfile $todayfile > $prepared";

        if ($DO_DEBUG_LOG) { print LOG "  $cmd\n"; }
        system($cmd);

        ## Now smooth the prepared file (into 'smoothed' file)
        $cmd  = "cat $prepared | $fins_smoother $tmp/slog$instance stdout $timeout $threads{$instance} |";
        $cmd .= "$Tspackle 1 '|.|.|.|.' '$yyyy-$mm-$dd $s_hr:$s_mn:00' '$YYYY-$MM-$DD $e_hr:$e_mn:00' ";
        $cmd .= "> $smoothed";

        if ($DO_DEBUG_LOG) { print LOG "  $cmd\n"; }
        system($cmd);

        ## Debug - print current status/results
        if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Smooth file for $instance finished.\n"; }

        ## Run the peak fins to get the max DC value from this smoothed file.
        $cmd = "tail -$peak_window $smoothed | $fins_peak";
        if ($DO_DEBUG_LOG) { print LOG "  $cmd\n"; }
        chomp($this_peak = `$cmd`);
        $this_peak += 0;

        ## Assign the value to $hostmax so we can change the border color if necessary.
        if ($this_peak > $hostmax) { $hostmax = $this_peak; }

        ## Check for an 'empty' smoothed file (all zeros); set a flag for this instance if so
        if ($this_peak == 0) { $empty{$instance} = 1; }

      } #end foreach instance in hostinstances

      if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Generating graph for $HOST...\n"; }
      $key = "center top horizontal samplen 6";
      &GenerateGraph($hostmax,$HOST,@insts);
      if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Graph generation for $HOST finished.\n"; }

#      ## Debug - print current status/results
#      if ($DO_DEBUG_LOG) { print LOG "$HOST instancelist is $instancelist\n"; }
#      if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Smoothing archive file for $HOST...\n"; }
#
#      $cmd = "cat $instancelist | $fins_smoother $tmp/slog$HOST stdout $timeout $threads{$HOST} |";
#      $cmd .= "$Tspackle 1 '|.|.|.|.' '$yyyy-$mm-$dd $s_hr:$s_mn:00' '$YYYY-$MM-$DD $e_hr:$e_mn:00' ";
#      $cmd .= "> $tmp/$HOST-smoothed.txt";
#
#      if ($DO_DEBUG_LOG) { print LOG "  $cmd\n"; }
#      system($cmd);
#
#      ## Debug - print current status/results
#      if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Smooth file for $HOST finished.\n"; }

      exit;
  
    } else {
      die "Can't fork: $! \n";
    }

  }

  ## Make the parent wait for the kids to finish before proceeding
  foreach $pid (keys(%kidpid)) { waitpid($kidpid{$pid}, 0); }

  ## Loop through each instance
  foreach $instance (@instances) {
    ## Run the peak fins to get the max DC value from this smoothed file.
    $smoothed = "$tmp/$instance-smoothed.txt";
    $cmd = "tail -$peak_window $smoothed | $fins_peak";
    if ($DO_DEBUG_LOG) { print LOG "  $cmd\n"; }
    chomp($this_peak = `$cmd`);
    $this_peak += 0;

    ## Assign the value to $MAX so we can change the border color if necessary.
    if ($this_peak > $MAX) { $MAX = $this_peak; }

    ## Check for an 'empty' smoothed file (all zeros); set a flag for this element if so
    if ($this_peak == 0) { $empty{$instance} = 1; }
  
    ## Find the most recent timestamp of the file (hour & minute)
    my $etime = substr(`tail -1 $smoothed`, 11, 5);
    $e_mn = substr($etime,3,2);
    $e_hr = substr($etime,0,2);
    if ($etime) { $end_time = timegm(0,$e_mn,$e_hr,$DD,$MM-1,$YYYY-1900); }
  }

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Generating graph for $env...\n"; }

  $key = "off";
  &GenerateGraph($MAX,"$env-instances",@instances);

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Calling DCdeploy.pl to send all graphs to $remotehost...\n"; }
  
  ## Nohup the external script and move on
  system("nohup $path/DCdeploy.pl & >/dev/null 2>&1");

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "[" . strftime("%T", gmtime) . "] Done.\n"; }

} #end sub SmoothRealTime


####################################################
## This sub will generate the config file for the ##
## graph (call to sub WriteConfig) and then it    ##
## will make system calls to gnuplot, et. al. to  ##
## have the graph created and moved into place    ##
## on the remote host (currently sysmon).         ##
####################################################
sub GenerateGraph {

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "  GenerateGraphs Begin.\n"; }

  my $peak = shift(@_);
  my $entity = shift(@_);
  my @components = @_;

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "  GenerateGraph: entity=$entity\n"; }
  if ($DO_DEBUG_LOG) { print LOG "  GenerateGraph: components=" . join(",", @components) . "\n"; }

  ##(now back calculate to find the first data point's timestamp
  ## and everything in between - store everything in an array.)
  undef(@labels);
  @labels = &GenerateLabels($end_time);
  $xTics = join(",", @labels);

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "  Writing Config file for $entity\n"; }

  ## Generate the config file
  &WriteConfig($peak, $yRange, $entity, @components);

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "  Running gnuplot for $entity\n"; }

  ## Plot the graph
  system("$gnuplot < $tmp/$entity.config >/dev/null 2>&1");
  &FixPSfile("$tmp/$entity.ps");
  system("$ps2jpg $tmp/$entity.ps 2>/dev/null");
  if ($entity !~ /$env/) {
    system("mkdir -p $tmp/$entity 2>/dev/null");
    system("cat $tmp/$entity.jpg | $jpegtran -rotate 90 > $tmp/$entity/DC-$entity.jpg");
  } else {
    system("cat $tmp/$entity.jpg | $jpegtran -rotate 90 > $tmp/DC-$entity.jpg");
  }

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "  GenerateGraphs Complete.\n"; }

} #end sub GenerateGraph


#################################################
## Subroutine to dynamically determine the     ##
## tickmark labels on the x axis of the graph. ##
#################################################
sub GenerateLabels {

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "    GenerateLabels Begin.\n"; }

  my $step = 5;
  my $backup = $step * 60;
  my $tick = $xRange;
  my $time = shift(@_);
  my ($m,$d,@lbls);
  while ($tick >= 0) {
    $h = strftime("%H", gmtime($time));
    $m = strftime("%M", gmtime($time));
    unshift(@lbls, "'$h:$m' $tick");
    $time -= $backup;
    $tick -= $backup;
  }

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "    GenerateLabels Complete.\n"; }

  return(@lbls);
} #end sub GenerateLabels


###################################################
## Subroutine to dynamically generate the config ##
## file necessary to create a graph of the data. ##
###################################################
sub WriteConfig {

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "    WriteConfig Begin.\n"; }

  my $peak = shift(@_);
  my $yrange = shift(@_);
  my $entity = shift(@_);
  my @components = sort(@_);
  my $outfile = "$entity.config";
  my $title = $entity;

  if ($DO_DEBUG_LOG) { print LOG "    WriteConfig: entity=$entity\n"; }
  if ($DO_DEBUG_LOG) { print LOG "    WriteConfig: components=" . join(",", @components) . "\n"; }
  if ($DO_DEBUG_LOG) { print LOG "    Writing config file $outfile\n"; }

  undef(@static);
  push(@static, "set term postscript color solid");
  push(@static, "set object 1 rect from screen 0, screen 0 to screen 1, screen 1 behind");
  push(@static, "set object 1 rect fc rgb '#000000' fs solid noborder");
  push(@static, "set object 2 rect from graph 0,0 to graph 1,1 back fc rgb '#000000'");
  push(@static, "set datafile commentschars \"*\"");
  push(@static, "set datafile separator \"|\"");
  push(@static, "set xlabel \"Time (GMT)\" 0,0");
  push(@static, "set ylabel \"Duty Cycle\"");
  push(@static, "set title \"$env - $title - $YYYY-$MM-$DD\"");
  push(@static, "set xtics ($xTics)");
  push(@static, "set xrange [0:$xRange]");
  push(@static, "set format x \"%b\'%y\"");
  push(@static, "set format y \"%Q\"");
  push(@static, "set timefmt \"%Y%m%d\"");
  push(@static, "set yrange [0:$yrange]");
  if ($entity =~ /$env/) {
    push(@static, "set tmargin 3");
    push(@static, "set lmargin 4");
    push(@static, "set rmargin 12");
    push(@static, "set bmargin 15");
  }
  push(@static, "set grid front lt 8");

  if ($peak >= $peak_error) {
    push(@static, "set border 15 lw 4 lt 1");
  } elsif ($peak >= $peak_warn) {
    push(@static, "set border 15 lw 3 lt 8");
  }
  push(@static, "set time");
  push(@static, "set key $key");

  open (OUT, ">$tmp/$outfile");
    print OUT join("\n", @static) . "\n";
    print OUT "set out \"$tmp/$entity.ps\"\n";
    print OUT "set style line 1 lt 2 lw 2 pt 3 ps 0.5\n";
    $first = shift(@components);
    print OUT "plot \"$tmp/$first-smoothed.txt\" using 4 ti \"$first\" w li $lt{'0'}";

    if (scalar(@components) > 0) {
      foreach $idx (0..$#components) {
        print OUT ", \\\n     \"$tmp/$components[$idx]-smoothed.txt\" using 4 ti \"$components[$idx]\" w li $lt{($idx+1)%$ltcnt}";
      }
    }

    print OUT "\n";
  close(OUT);

  ## Debug - print current status/results
  if ($DO_DEBUG_LOG) { print LOG "    WriteConfig Complete.\n"; }
} #end sub WriteConfig


###################################
## Tweak the PS file before it   ##
## gets turned into a JPEG image ##
###################################
sub FixPSfile {
  my $file = shift(@_);
  system("cp $file $file.bak");
  system("$perl -i -pe 's/LC7 \\\{1 0\.3 0\\\} def/LC7 \\\{1 1 1\\\} def/g' $file");
  system("$perl -i -pe 's/LCb DL/LCw DL/g' $file");
  system("$perl -i -pe 's/50 50/0 0/g' $file");
  system("$perl -i -pe 's/554 770/612 792/g' $file");
  system("$perl -i -pe 's/-5040/-6120/g' $file");
  system("$perl -i -pe 's/-5039 7199 0 0 5039/-6119 7919 0 0 6119/g' $file");
  system("$perl -i -pe 's/6119 h/6119 h\n0 1080 translate\n0 0 N/g' $file");
} #end sub FixPSfile
