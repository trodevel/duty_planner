#!/usr/bin/perl -w

#
# Duty Planner.
#
# Copyright (C) 2015 Sergey Kolevatov
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

# $Id $
# SKV FB10

# 1.0 - FB10 - initial commit
# 1.1 - FC08 - 1. bugfix: leading zeros from exception week were not cut 2. switched output to CSV
# 1.2 - FC16 - bugfix: empty lines were not skipped
# 1.3 - FC16 - tries to reiterate type_2 when no resource can be found for type_3
# 1.4 - 16318 - added parameter last week
# 1.5 - 16318 - defined resource type for exceptions
# 1.6 - 16318 - added dump_resources()
# 1.7 - 16319 - added reading of status file
# 1.8 - 16c06 - added output of the first and the last days of the week

my $VER="1.8";

###############################################

use strict;
use warnings;
use 5.010;

use Time::Piece;    # date_to_week()
require 'DateTools.pm';

###############################################

sub add_resource_to_set
{
    my $line = shift;
    my $type = shift;
    my $map_stat_ref = shift || die "no stat map";
    my $res = shift;

    if( exists $map_stat_ref->{$res} )
    {
        print "ERROR: resource $res already defined for type $type, line $line.\n";
        exit;
    }
    else
    {
        $map_stat_ref->{$res} = 0;
        print STDERR "DBG: added resource $res to type $type.\n";       # DBG
    }
}

###############################################

sub update_resource_status
{
    my $line = shift;
    my $type = shift;
    my $map_stat_ref = shift || die "no stat map";
    my $res_stat = shift;

    my @wrds = split( /:/, $res_stat );

    print STDERR "DBG: line $line, res_stat = $res_stat, num wrds = $#wrds, $wrds[0], $wrds[1]\n";

    if( $#wrds != 1 )
    {
        print "ERROR: broken status for type $type, line $line.\n";
        exit;
    }

    my $res = $wrds[0];
    my $status = $wrds[1] + 0;

    print STDERR "DBG: updated status for resource $res = $status of type $type, line $line.\n";

    if( not exists $map_stat_ref->{$res} )
    {
        print "ERROR: unknwon resource $res for type $type, line $line.\n";
        exit;
    }

    $map_stat_ref->{$res} = $status;
}

###############################################

# map resource stat

# type -> name -> stat

sub parse_resource
{
    my $line = shift;
    my $a = shift;
    my $map_type_on_stat_ref = shift || die "no type on stat map";

    my @wrds = split( / /, $a );

    shift( @wrds );

    my $type=$wrds[0];

    shift( @wrds );

    print STDERR "DBG: resource type: " . $type . "\n";       # DBG

    my $stat_ref;

    if( exists $map_type_on_stat_ref->{$type} )
    {
        $stat_ref = $map_type_on_stat_ref->{$type};
        print STDERR "DBG: existing resource type: " . $type . "\n";       # DBG
    }
    else
    {
        my %map_stat;

        $stat_ref = \%map_stat;

        $map_type_on_stat_ref->{$type} = $stat_ref;
        print STDERR "DBG: new resource type: " . $type . "\n";       # DBG
    }


    foreach( @wrds )
    {
        add_resource_to_set( $line, $type, $stat_ref, $_ );
    }
}

###############################################

# map resource stat

# type -> name -> stat

sub parse_resource_status
{
    my $line = shift;
    my $a = shift;
    my $map_type_on_stat_ref = shift || die "no type on stat map";

    my @wrds = split( / /, $a );

    shift( @wrds );

    my $type=$wrds[0];

    shift( @wrds );

    print STDERR "DBG: resource type: $type\n";       # DBG

    if( not exists $map_type_on_stat_ref->{$type} )
    {
        print "FATAL: unknown resource type: $type, line $line\n";
        exit;
    }

    my $stat_ref = $map_type_on_stat_ref->{$type};

    foreach( @wrds )
    {
        update_resource_status( $line, $type, $stat_ref, $_ );
    }
}

###############################################

sub date_to_week
{

    my $date = shift;

    my $dt = Time::Piece->strptime($date, '%Y-%m-%d');

    my $week = $dt->strftime('%W');

    return $week + 0;
}

###############################################

sub convert_date_or_week_to_week
{
    my $date_or_week = shift;

    if( m#cw([0-9]*)# )
    {
        return $1 + 0;
    }
    elsif ( m#([0-9]*)-([0-9]*)-([0-9]*)#)
    {
        return date_to_week( $_ );
    }
    else
    {
        print "FATAL: date in unknown format $_\n";
        exit;
    }

    return 0;
}


###############################################

sub add_exception_to_list
{
    my $line = shift;
    my $name = shift;
    my $except_list_ref = shift || die "no except list";
    my $date_or_week = shift;

    my $week = convert_date_or_week_to_week( $date_or_week );

    #print STDERR "DBG: $date_or_week -> week $week\n";       # DBG

    if( exists $except_list_ref->{$week} )
    {
        print "WARNING: week $week is already added to exception list for resource $name, line $line.\n";
    }
    else
    {
        $except_list_ref->{$week} = 1;
        print STDERR "DBG: added week $week to exception list for resource $name.\n";       # DBG
        #print STDERR "DBG: " . $except_list_ref->{$week} . "\n";       # DBG
    }
}

###############################################

# exception map

# name -> type -> array: week

sub parse_exception
{
    my $line = shift;
    my $a = shift;
    my $map_name_on_except_ref = shift || die "no 'name on except' map";

    my @wrds = split( / /, $a );

    if( $#wrds < 1 )
    {
        print "ERROR: exception without resource name, line $line.\n";
        exit;
    }

    if( $#wrds < 2 )
    {
        print "ERROR: duty type for exception is not defined, line $line.\n";
        exit;
    }


    if( $#wrds < 3 )
    {
        print "ERROR: empty exception list for resource, line $line.\n";
        exit;
    }

    shift( @wrds );

    my $name = $wrds[0];
    my $type = $wrds[1];

    shift( @wrds );
    shift( @wrds );

    print STDERR "DBG: exception for resource $name, type $type.\n";       # DBG

    my $except_list_ref;

    if( exists $map_name_on_except_ref->{$name} )
    {
        if( exists $map_name_on_except_ref->{$name}->{$type} )
        {
            print STDERR "DBG: exception for existing resource $name.\n";       # DBG
            $except_list_ref = $map_name_on_except_ref->{$name}->{$type};
        }
        else
        {
            print STDERR "DBG: exception for existing resource $name, for NEW resource type $type.\n";       # DBG
            my %except_list;
            $except_list_ref = \%except_list;
            $map_name_on_except_ref->{$name}->{$type} = $except_list_ref;
        }
    }
    else
    {
        print STDERR "DBG: exception for NEW resource $name.\n";       # DBG

        my %except_list;

        $except_list_ref = \%except_list;

        $map_name_on_except_ref->{$name}->{$type} = $except_list_ref;
    }


    foreach( @wrds )
    {
        add_exception_to_list( $line, $name, $except_list_ref, $_ );
    }
}

###############################################

sub read_status
{
    my $filename = shift;
    my $map_res_ref = shift;

    unless( -e $filename )
    {
        print "WARNING: status file $filename doesn't exist\n";
        return;
    }

    my $lines = 0;
    my $resrc_lines=0;

    print "Reading status $filename ...\n";
    open RN, "<", $filename;

    while( <RN> )
    {
        chomp;
        $lines++;


        # skip empty lines
        s/^\s+//g; # no leading white spaces
        next unless length;

# sample status file:
#type td res3:1 res8:6 res1:1 res2:0 skv:0 res4:0
#type 18p res3:1 res8:2 res2:1 res9:3 res7:2 res4:2 res5:2
#type od res3:1 res1:1 res2:2 res9:0 res6:1

    if ( m#type ([a-zA-Z0-9]*) #)
    {
        print STDERR "DBG: resource line $_\n";
        $resrc_lines++;

        parse_resource_status( $lines, $_, $map_res_ref );
    }
    else
    {
        print STDERR "DBG: unknown line $lines, $_\n";
        exit;
    }
}

close RN;

}

###############################################

sub read_resources
{
    my $filename = shift;
    my $map_res_ref = shift;
    my $map_except_ref = shift;

    unless( -e $filename )
    {
        print "ERROR: resource file $filename doesn't exist\n";
        exit;
    }

    my $lines = 0;
    my $except_lines=0;
    my $resrc_lines=0;

    print "Reading resources $filename ...\n";
    open RN, "<", $filename;

    while( <RN> )
    {
        chomp;
        $lines++;


        # skip empty lines
        s/^\s+//g; # no leading white spaces
        next unless length;

# sample resource file:
#duty_resource td res3 res8 res1 res2 skv res4
#duty_resource 18p res3 res8 res2 res9 res7 res4 res5
#duty_resource od res3 res1 res2 res9 res6
#except res3 * cw17 2015-5-6 2015-5-7
#except res8 18p
#except res2 od

    if( m#except .*# )
    {
        print STDERR "DBG: exception line $_\n";
        $except_lines++;

        parse_exception( $lines, $_, $map_except_ref );
    }
    elsif ( m#duty_resource ([a-zA-Z0-9]*) #)
    {
        print STDERR "DBG: resource line $_\n";
        $resrc_lines++;

        parse_resource( $lines, $_, $map_res_ref );
    }
    else
    {
        print STDERR "DBG: unknown line $lines, $_\n";
        next;
    }
}

close RN;

}
###############################################

sub is_constrained
{
    my ( $res, $except_1, $except_2, $except_3, $map_except_ref, $type, $week ) = @_;

    if( ( $res eq $except_1 ) || ( $res eq $except_2 ) || ( $res eq $except_3 ) )
    {
        return 1;
    }

    my $type_any = "*";

    if( exists $map_except_ref->{$res} )
    {
        # check ANY duty type
        if( exists $map_except_ref->{$res}->{$type_any} )
        {
            if( exists $map_except_ref->{$res}->{$type_any}->{$week} )
            {
                return 1;
            }
        }

        # check given duty type
        if( exists $map_except_ref->{$res}->{$type} )
        {
            if( exists $map_except_ref->{$res}->{$type}->{$week} )
            {
                return 1;
            }
        }
    }

    return 0;
}

###############################################

sub find_min_resource
{
    my $map_stat_ref = shift;
    my $except_1 = shift;
    my $except_2 = shift;
    my $except_3 = shift;
    my $map_except_ref = shift;
    my $week = shift;
    my $type = shift;

    my $res_min_name = '';
    my $res_min = -1;


    foreach my $res ( sort keys %$map_stat_ref )
    {
        # first iteration to fill initial element
        if( $res_min == -1 )
        {
            if( is_constrained( $res, $except_1, $except_2, $except_3, $map_except_ref, $type, $week ) )
            {
                print STDERR "DBG: ignore $res (except)\n";
                next;
            }

            $res_min_name = $res;
            $res_min = $map_stat_ref->{$res};
            next;
        }

        if( $map_stat_ref->{$res} < $res_min )
        {
            if( is_constrained( $res, $except_1, $except_2, $except_3, $map_except_ref, $type, $week ) )
            {
                print STDERR "DBG: ignore $res (except)\n";
                next;
            }

            $res_min_name = $res;
            $res_min      = $map_stat_ref->{$res};
        }
    }

    return ($res_min_name, $res_min);
}

###############################################
sub find_min_resource_type
{
    my $type = shift;
    my $except_1 = shift;
    my $except_2 = shift;
    my $except_3 = shift;
    my $map_res_ref = shift;
    my $map_except_ref = shift;
    my $week = shift;

    print STDERR "DBG: find_min_resource_type $type $except_1 $except_2\n";


    if( not exists $map_res_ref->{$type} )
    {
        print "FATAL: cannot find resource type $type\n";       # DBG
        exit
    }

    my $stat_ref = $map_res_ref->{$type};

    my ( $res, $res_min ) = find_min_resource( $stat_ref, $except_1, $except_2, $except_3, $map_except_ref, $week, $type );

    print STDERR "DBG: found $type -> $res ($res_min)\n"; # DBG

    return ( $res, $res_min );
}

###############################################

sub check_iter_result
{
    my $res = shift;
    my $type = shift;
    my $iter = shift;


    if( $res == -1 )
    {
        print "ERROR: cannot find resource of type $type, week $iter\n";
        exit;
    }
}

###############################################

sub validate_results
{
    my( $res_1, $res_2, $res_3 ) = @_;

    if( $res_1 eq $res_2 )
    {
        print "ERROR: validation failed: $res_1 $res_2\n";
        exit;
    }

    if( $res_1 eq $res_3 )
    {
        print "ERROR: validation failed: $res_1 $res_3\n";
        exit;
    }

    if( $res_2 eq $res_3 )
    {
        print "ERROR: validation failed: $res_2 $res_3\n";
        exit;
    }
}

###############################################

sub get_absence_for_week
{
    my ( $map_except_ref, $week ) = @_;

    my @res=();

    my $type_any = "*";

    foreach my $res ( sort keys %$map_except_ref )
    {
        #print STDERR "DBG: get_absence_for_week $week: res $res "; # DBG

        if( exists $map_except_ref->{$res}->{$type_any} )
        {
            if( exists $map_except_ref->{$res}->{$type_any}->{$week} )
            {
                #print "ABS";
                push @res, $res;
            }
        }

        #print "\n";
    }

    return @res;
}

###############################################
sub find_plan_for_week
{
    my $map_res_ref = shift;
    my $map_except_ref = shift;

    my $i = shift;

    my $type_1 = shift;
    my $type_2 = shift;
    my $type_3 = shift;

    my $prev_duty = shift;


    my ( $res_1, $res_min_1 ) = find_min_resource_type( $type_1, 0, $prev_duty, 0, $map_res_ref, $map_except_ref, $i );
    check_iter_result( $res_min_1, $type_1, $i );

    my ( $res_2, $res_min_2 ) = find_min_resource_type( $type_2, $res_1, $prev_duty, 0, $map_res_ref, $map_except_ref, $i );
    check_iter_result( $res_min_2, $type_2, $i );

    my ( $res_3, $res_min_3 ) = find_min_resource_type( $type_3, $res_1, $res_2, 0, $map_res_ref, $map_except_ref, $i );

    # try to reiterate previous step
    if( $res_min_3 == -1 )
    {
        printf STDERR "DBG: trying to reiterate ***\n";

        my ( $new_res_2, $new_res_min_2 ) = find_min_resource_type( $type_2, $res_1, $prev_duty, $res_2, $map_res_ref, $map_except_ref, $i );
        check_iter_result( $new_res_min_2, $type_2, $i );

        ( $res_2, $res_min_2 ) = ( $new_res_2, $new_res_min_2 );

        ( $res_3, $res_min_3 ) = find_min_resource_type( $type_3, $res_1, $res_2, 0, $map_res_ref, $map_except_ref, $i );
        check_iter_result( $res_min_3, $type_3, $i );

    }

    return ( $res_1, $res_2, $res_3 );
}

###############################################

sub generate_plan
{
    my $year        = shift;
    my $map_res_ref = shift;
    my $map_except_ref = shift;

    my $week = shift;
    my $last_week = shift;

    my $type_1 = shift;
    my $type_2 = shift;
    my $type_3 = shift;

    my $prev_duty = 0;

    #print "week: $type_1 $type_2 $type_3\n";
    print "week;mm1;dd1;yy2;mm2;dd2;$type_1;$type_2;$type_3;exceptions;stat1;stat2;stat3;\n";

    for( my $i = $week; $i <= $last_week; $i = $i + 1 )
    {

        my ( $res_1, $res_2, $res_3 ) = find_plan_for_week( $map_res_ref, $map_except_ref, $i, $type_1, $type_2, $type_3, $prev_duty );

        validate_results( $res_1, $res_2, $res_3 );

        $prev_duty = $res_3;

        $map_res_ref->{$type_1}->{$res_1}++;
        $map_res_ref->{$type_2}->{$res_2}++;
        $map_res_ref->{$type_3}->{$res_3}++;

        my @absence = get_absence_for_week( $map_except_ref, $i );

        my( $year1, $month1, $day1 ) = DateTools::get_monday_of_week( $i, $year );
        my( $year2, $month2, $day2 ) = DateTools::get_sunday_of_week( $i, $year );

        #print "$i: $res_1 $res_2 $res_3 absence: @absence ---- $map_res_ref->{$type_1}->{$res_1} $map_res_ref->{$type_2}->{$res_2} $map_res_ref->{$type_3}->{$res_3}\n";
        print "$i;$month1;$day1;$year2;$month2;$day2;$res_1;$res_2;$res_3;@absence;$map_res_ref->{$type_1}->{$res_1};$map_res_ref->{$type_2}->{$res_2};$map_res_ref->{$type_3}->{$res_3};\n";
    }
}


###############################################

sub dump_resources
{
    my $map_res_ref = shift;

    print "\n";
    print "resources:\n";
    print "\n";

    foreach my $type ( sort keys %$map_res_ref )
    {
        print "type $type:";
        foreach my $name ( sort keys $map_res_ref->{$type} )
        {
            print " $name:" . $map_res_ref->{$type}->{$name};
        }
        print "\n";
    }
}

###############################################

sub dump_exceptions
{
    my $map_except_ref = shift;

    print "\n";
    print "exceptions:\n";
    print "\n";

    foreach my $resu ( sort keys %$map_except_ref )
    {
        foreach my $type ( sort keys $map_except_ref->{$resu} )
        {
            print "resource $resu: type $type:";
            foreach my $week ( sort keys $map_except_ref->{$resu}->{$type} )
            {
                print " $week";
            }
            print "\n";
        }
    }
}

###############################################
print "duty_planner ver. $VER\n";

my $num_args = $#ARGV + 1;
if( $num_args < 3 || $num_args > 5 )
{
    print STDERR "\nUsage: duty_planner.sh <year> <resources.txt> <status.txt> [<first_week> [<last_week>] ]\n";
    exit;
}

my $year        = $ARGV[0];
my $resources   = $ARGV[1];
my $status      = $ARGV[2];

my $week = 1;
my $last_week = 52;

if( $num_args >= 4 )
{
    $week = $ARGV[3];
}
if( $num_args == 5 )
{
    $last_week = $ARGV[4];
}

print STDERR "year       = $year\n";
print STDERR "resources  = $resources\n";
print STDERR "status     = $status\n";
print STDERR "first week = $week\n";
print STDERR "last week  = $last_week\n";

my %map_res;
my %map_except;

read_resources( $resources, \%map_res, \%map_except );

read_status( $status, \%map_res );

dump_resources( \%map_res );

dump_exceptions( \%map_except );

print "\n";

generate_plan( $year, \%map_res, \%map_except, $week, $last_week, 'td', '18p', 'od' );

dump_resources( \%map_res );

print "\n";

exit;


##########################
