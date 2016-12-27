#!/usr/bin/perl

# 1.1 - 16c27 - bugfix: get_sunday_of_week() returned wrong day

package DateTools;

use Date::Calc qw(:all);

sub get_monday_of_week
{
    my( $week, $year ) = @_;

    return Monday_of_Week( $week, $year );
}

sub get_sunday_of_week
{
    my( $week, $year ) = @_;

    my( $year2, $month2, $day2 ) = get_monday_of_week( $week, $year );

    return Add_Delta_Days( $year2, $month2, $day2, 6 );
}

1;
