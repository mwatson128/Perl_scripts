#!/bin/perl

print "What is the radius of the circle?\n";
chomp ($r = <>);

$diameter = (2 * $r);
$area = (3.14 * ($r ** 2));
$cir = ($diameter * 3.14);

print "Radius: $r\n Diameter: $diameter\n Circumference: $cir\n Area: $area\n";

