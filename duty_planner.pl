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


my $VER="1.0";

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

    return $week;
}

###############################################

sub convert_date_or_week_to_week
{
    my $date_or_week = shift;

    if( m#cw([0-9]*)# )
    {
        return $1;
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

    if( exists $except_list_ref->{$week} )
    {
        print STDERR "WARNING: week $week is already added to exception list for resource $name, line $line.\n";
    }
    else
    {
        $except_list_ref->{$week} = 1;
        print STDERR "DBG: added week $week to exception list for resource $name.\n";       # DBG
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
        print STDERR "DBG: exception for resource $name.\n";       # DBG

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
    my $res_map_ref = shift;
    my $excep_map_ref = shift;

    unless( -e $filename )
    {
        print STDERR "ERROR: resource file $filename doesn't exist\n";
        exit;
    }

    my $lines = 0;
    my $except_lines=0;
    my $resrc_lines=0;

    my %map_res;
    my %map_except;


    print "Reading $filename...\n";
    open RN, "<", $filename;

    while( <RN> )
    {
        chomp;
        $lines++;

# sample tick:
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

        parse_exception( $lines, $_, \%map_except );
    }
    elsif ( m#([a-zA-Z0-9]*) #)
    {
        print STDERR "DBG: resource line $_\n";
        $resrc_lines++;

        parse_resource( $lines, $_, \%map_res );
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

print "duty_planner ver. $VER\n";

$num_args = $#ARGV + 1;
if( $num_args < 2 || $num_args > 3 )
{
    print STDERR "\nUsage: duty_planner.sh <resources.txt> <status.txt> [<week>]\n";
    exit;
}

$resources = $ARGV[0];
shift( @ARGV );

read_resources( $resources );

exit;


##########################
