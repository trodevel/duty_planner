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

sub add_resource_to_set
{
    my $type = shift;
    my $map_stat_ref = shift || die "no stat map";
    my $res = shift;

    if( exists $map_stat_ref->{$res} )
    {
        print STDERR "ERROR: resource $res already defined for type $type.\n";
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
        add_resource_to_set( $type, $stat_ref, $_ );
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
#except ac cw17 506 507
#except sk
#except abu

    if( m#except .*# )
    {
        print STDERR "DBG: exception line $_\n";
        $except_lines++;
    }
    elsif ( m#([a-zA-Z0-9]*) #)
    {
        print STDERR "DBG: resource line $_\n";
        $resrc_lines++;

        parse_resource( $_, \%map_res );
    }
    else
    {
        print STDERR "DBG: unknown line $_\n";
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
