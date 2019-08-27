#!/usr/bin/perl

# This is a script that displays the current user.
# It uses the HOME env variable, as others are not set.

($name, $all_else) = split /:/, getpwuid $<, 2 ;

print "\n\n", "*" x 15, "\n    ";
print $name;
print "\n", "*" x 15, "\n\n";

