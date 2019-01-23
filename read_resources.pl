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
# 1.9 - 16c27 - 1. ignored empty exceptions in exception file 2. added one more check to validate_results() 3. added output of the first year
# 1.10 - 17101 - 1. moved reading of status and resources into a separate file
# 1.11 - 19123 - bugfix: date_to_week() didn't return ISO week number

###############################################

use strict;
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

# should return ISO week number
# http://man7.org/linux/man-pages/man3/strftime.3.html

#       %V     The ISO 8601 week number (see NOTES) of the current year as a
#              decimal number, range 01 to 53, where week 1 is the first week
#              that has at least 4 days in the new year.  See also %U and %W.
#              (Calculated from tm_year, tm_yday, and tm_wday.)  (SU)

    my $date = shift;

    my $dt = Time::Piece->strptime($date, '%Y-%m-%d');

    my $week = $dt->strftime('%V');

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
        print "WARNING: empty exception list for resource, line $line.\n";
        return;
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
1;
