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


my $VER="1.1";

###############################################

#use strict;
use warnings;
use 5.010;

use Time::Piece;    # date_to_week()

###############################################

sub add_resource_to_set
{
    my $line = shift;
    my $type = shift;
    my $map_stat_ref = shift || die "no stat map";
    my $res = shift;

    if( exists $map_stat_ref->{$res} )
    {
        print STDERR "ERROR: resource $res already defined for type $type, line $line.\n";
        exit;
    }
    else
    {
        $map_stat_ref->{$res} = 0;
        print "DBG: added resource $res to type $type.\n";       # DBG
    }
}

###############################################

sub parse_resource
{
    my $line = shift;
    my $a = shift;
    my $map_type_on_stat_ref = shift || die "no type on stat map";

    my @wrds = split( / /, $a );

    my $type=$wrds[0];
    shift( @wrds );

    print "DBG: resource type: " . $type . "\n";       # DBG

    my $stat_ref;

    if( exists $map_type_on_stat_ref->{$type} )
    {
        $stat_ref = $map_type_on_stat_ref->{$type};
        print "DBG: existing resource type: " . $type . "\n";       # DBG
    }
    else
    {
        my %map_stat;

        $stat_ref = \%map_stat;

        $map_type_on_stat_ref->{$type} = $stat_ref;
        print "DBG: new resource type: " . $type . "\n";       # DBG
    }


    foreach( @wrds )
    {
        add_resource_to_set( $line, $type, $stat_ref, $_ );
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
        print STDERR "FATAL: date in unknown format $_\n";
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

    #print "DBG: $date_or_week -> week $week\n";       # DBG

    if( exists $except_list_ref->{$week} )
    {
        print STDERR "WARNING: week $week is already added to exception list for resource $name, line $line.\n";
    }
    else
    {
        $except_list_ref->{$week} = 1;
        print STDERR "DBG: added week $week to exception list for resource $name.\n";       # DBG
        #print STDERR "DBG: " . $except_list_ref->{$week} . "\n";       # DBG
    }
}

###############################################

sub parse_exception
{
    my $line = shift;
    my $a = shift;
    my $map_name_on_except_ref = shift || die "no 'name on except' map";

    my @wrds = split( / /, $a );

    if( $#wrds < 1 )
    {
        print STDERR "ERROR: exception without resource name, line $line.\n";
        exit;
    }

    if( $#wrds < 2 )
    {
        print STDERR "WARNING: empty exception list for resource, line $line.\n";
    }

    shift( @wrds );

    my $name=$wrds[0];

    shift( @wrds );

    print STDERR "DBG: exception for resource $name.\n";       # DBG

    my $except_list_ref;

    if( exists $map_name_on_except_ref->{$name} )
    {
        print STDERR "DBG: exception for existing resource $name.\n";       # DBG
        $except_list_ref = $map_name_on_except_ref->{$name};
    }
    else
    {
        print STDERR "DBG: exception for NEW resource $name.\n";       # DBG

        my %except_list;

        $except_list_ref = \%except_list;

        $map_name_on_except_ref->{$name} = $except_list_ref;
    }


    foreach( @wrds )
    {
        add_exception_to_list( $line, $name, $except_list_ref, $_ );
    }
}

###############################################

sub read_resources
{
    my $filename = shift;
    my $map_res_ref = shift;
    my $map_except_ref = shift;

    unless( -e $filename )
    {
        print STDERR "ERROR: resource file $filename doesn't exist\n";
        exit;
    }

    my $lines = 0;
    my $except_lines=0;
    my $resrc_lines=0;

    print "Reading $filename...\n";
    open RN, "<", $filename;

    while( <RN> )
    {
        chomp;
        $lines++;

# sample resource file:
#td ac sk ab abu skv ol
#18p ac sk abu skv ol am hk
#od ac ab abu skv mk
#except ac cw17 2015-5-6 2015-5-7
#except sk
#except abu

    if( m#except .*# )
    {
        print STDERR "DBG: exception line $_\n";
        $except_lines++;

        parse_exception( $lines, $_, $map_except_ref );
    }
    elsif ( m#([a-zA-Z0-9]*) #)
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
    my ( $res, $except_1, $except_2, $map_except_ref, $week ) = @_;

    if( ( $res eq $except_1 ) || ( $res eq $except_2 ) )
    {
        return 1;
    }

    if( exists $map_except_ref->{$res} )
    {
        if( exists $map_except_ref->{$res}->{$week} )
        {
            return 1;
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
    my $map_except_ref = shift;
    my $week = shift;

    my $res_min_name = '';
    my $res_min = -1;


    foreach my $res ( sort keys %$map_stat_ref )
    {
        # first iteration to fill initial element
        if( $res_min == -1 )
        {
            if( is_constrained( $res, $except_1, $except_2, $map_except_ref, $week ) )
            {
                print "DBG: ignore $res (except)\n";
                next;
            }

            $res_min_name = $res;
            $res_min = $map_stat_ref->{$res};
            next;
        }

        if( $map_stat_ref->{$res} < $res_min )
        {
            if( is_constrained( $res, $except_1, $except_2, $map_except_ref, $week ) )
            {
                print "DBG: ignore $res (except)\n";
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
    my $map_res_ref = shift;
    my $map_except_ref = shift;
    my $week = shift;

    #print "DBG: find_min_resource_type $type $except_1 $except_2\n";


    if( not exists $map_res_ref->{$type} )
    {
        print STDERR "FATAL: cannot find resource type $type\n";       # DBG
        exit
    }

    my $stat_ref = $map_res_ref->{$type};

    return find_min_resource( $stat_ref, $except_1, $except_2, $map_except_ref, $week );
}

###############################################

sub check_iter_result
{
    my $res = shift;
    my $type = shift;
    my $iter = shift;


    if( $res == -1 )
    {
        print STDERR "ERROR: cannot find resource of type $type, week $iter\n";
        exit;
    }
}

###############################################

sub validate_results
{
    my( $res_1, $res_2, $res_3 ) = @_;

    if( $res_1 eq $res_2 )
    {
        print STDERR "ERROR: validation failed: $res_1 $res_2\n";
        exit;
    }

    if( $res_1 eq $res_3 )
    {
        print STDERR "ERROR: validation failed: $res_1 $res_3\n";
        exit;
    }

    if( $res_2 eq $res_3 )
    {
        print STDERR "ERROR: validation failed: $res_2 $res_3\n";
        exit;
    }
}

###############################################

sub get_absence_for_week
{
    my ( $map_except_ref, $week ) = @_;

    my @res=();

    foreach my $res ( sort keys %$map_except_ref )
    {
        #print "DBG: get_absence_for_week $week: res $res "; # DBG

        if( exists $map_except_ref->{$res}->{$week} )
        {
            #print "ABS";
            push @res, $res;
        }

        #print "\n";
    }

    return @res;
}

###############################################

sub generate_plan
{
    my $map_res_ref = shift;
    my $map_except_ref = shift;

    my $week = shift;

    my $type_1 = shift;
    my $type_2 = shift;
    my $type_3 = shift;

    my $prev_duty = 0;

    #print "week: $type_1 $type_2 $type_3\n";
    print "week;$type_1;$type_2;$type_3;absence;stat1;stat2;stat3;\n";

    for( $i = $week; $i <= 52; $i = $i + 1 )
    {

        my ( $res_1, $res_min_1 ) = find_min_resource_type( $type_1, 0, $prev_duty, $map_res_ref, $map_except_ref, $i );
        check_iter_result( $res_min_1, $type_1, $i );

        my ( $res_2, $res_min_2 ) = find_min_resource_type( $type_2, $res_1, $prev_duty, $map_res_ref, $map_except_ref, $i );
        check_iter_result( $res_min_2, $type_2, $i );

        my ( $res_3, $res_min_3 ) = find_min_resource_type( $type_3, $res_1, $res_2, $map_res_ref, $map_except_ref, $i );
        check_iter_result( $res_min_3, $type_3, $i );

        validate_results( $res_1, $res_2, $res_3 );

        $prev_duty = $res_3;

        $map_res_ref->{$type_1}->{$res_1}++;
        $map_res_ref->{$type_2}->{$res_2}++;
        $map_res_ref->{$type_3}->{$res_3}++;

        my @absence = get_absence_for_week( $map_except_ref, $i );

        #print "$i: $res_1 $res_2 $res_3 absence: @absence ---- $map_res_ref->{$type_1}->{$res_1} $map_res_ref->{$type_2}->{$res_2} $map_res_ref->{$type_3}->{$res_3}\n";
        print "$i;$res_1;$res_2;$res_3;@absence;$map_res_ref->{$type_1}->{$res_1};$map_res_ref->{$type_2}->{$res_2};$map_res_ref->{$type_3}->{$res_3};\n";
    }
}


###############################################

print "duty_planner ver. $VER\n";

my $num_args = $#ARGV + 1;
if( $num_args < 2 || $num_args > 3 )
{
    print STDERR "\nUsage: duty_planner.sh <resources.txt> <status.txt> [<week>]\n";
    exit;
}

my $resources = $ARGV[0];
my $status = $ARGV[1];

my $week = 1;
if( $num_args == 3 )
{
    $week = $ARGV[2];
}

print STDERR "resources  = $resources\n";
print STDERR "status     = $status\n";
print STDERR "first week = $week\n";

my %map_res;
my %map_except;

read_resources( $resources, \%map_res, \%map_except );

generate_plan( \%map_res, \%map_except, $week, 'td', '18p', 'od' );

exit;


##########################
