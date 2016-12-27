#!/usr/bin/perl

#
# Convert output of the Duty Planner in Wikimedia format
#
# Copyright (C) 2016 Sergey Kolevatov
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#

sub format_date
{
    my( $y, $m, $d ) = @_;

    my $res = undef;

    if( defined $y && $y ne '' )
    {
        $res = sprintf( "%02d.%02d.%04d", $d, $m, $y );
    }
    else
    {
        $res = sprintf( "%02d.%02d", $d, $m );
    }

    return $res;
}

open(INPUT, "< input.csv")
       or die "Couldn't open file for reading: $!\n";
open(OUTPUT, "> output.txt")
       or die "Couldn't open file for writing: $!\n";   

printf OUTPUT "{|- bgcolor=DDE8EB border=\"1\" cellpadding=\"3\" cellspacing=\"0\"\n";
printf OUTPUT "| <b>Calendar Week</b> || <b>Duty 1</b> || <b>Duty 2</b> || <b>Duty 3</b> || <b>Absent</b>\n|-\n";

while( <INPUT> )
{
    @fields = split(";");
    printf OUTPUT "\|" . sprintf( "%02d", $fields[0] ) . " (" . format_date( undef, $fields[2], $fields[3] ) . " - " . format_date( $fields[4], $fields[5], $fields[6] ) . ")\n\|$fields[7]\n\|$fields[8]\n\|$fields[9]\n\|". ( join ', ', split / /, $fields[10] ) ."\n\|-\n" ;
}

printf OUTPUT "|}\n";

close INPUT;
close OUTPUT;
