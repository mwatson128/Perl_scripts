#! /bin/perl
# some perl stuff i use alot - michaelj

%enddates = (
  "01" => 31,
  "02" => 28,
  "03" => 31,
  "04" => 30,
  "05" => 31,
  "06" => 30,
  "07" => 31,
  "08" => 31,
  "09" => 30,
  "10" => 31,
  "11" => 30,
  "12" => 31,
);

sub numfix {
  my $x = shift;
  $tmp = $x =~ tr/0-9//;
  if ($tmp == 1) { return "0$x"; }
  return "$x";
}

sub pad {
  my ($x, $length) = @_;
  $num = $x;
  for ($i = length($x); $i < $length; $i++) {
    $num = "0$num";
  }
  return $num;
}

sub numdays {
  my ($month, $year) = @_;
  if (0 == $year%4 && 2 == $month) {
    return 29;
  }
  else {
    return $enddates{numfix($month)};
  }
}

sub SENDLINE {
  my ($length) = @_;
  for ($i = 0; $i < $length; $i++) {
    print "-";
  }
  print "\n";
}

sub num2month {
  $_ = @_[0];

  SWITCH: {
  /1/   && do { $month = "JAN"; last SWITCH; };
  /2/   && do { $month = "FEB"; last SWITCH; };
  /3/   && do { $month = "MAR"; last SWITCH; };
  /4/   && do { $month = "APR"; last SWITCH; };
  /5/   && do { $month = "MAY"; last SWITCH; };
  /6/   && do { $month = "JUN"; last SWITCH; };
  /7/   && do { $month = "JUL"; last SWITCH; };
  /8/   && do { $month = "AUG"; last SWITCH; };
  /9/   && do { $month = "SEP"; last SWITCH; };
  /10/  && do { $month = "OUT"; last SWITCH; };
  /11/  && do { $month = "NOV"; last SWITCH; };
  $month = "DEC";
  }

  return $month;
}
