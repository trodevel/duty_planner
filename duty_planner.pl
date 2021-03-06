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
# 1.10 - 17102 - 1. moved reading of status and resources into a separate file 2. minor: renaming
# 1.11 - 17b29 - 1. added command line arguments 2. added output into file
# 1.12 - 18702 - minor: refinements in debug output
# 1.13 - 20320 - updated to a newer Perl 5.16

my $VER="1.13";

###############################################

use strict;
use warnings;
use 5.010;
use Getopt::Long;

require 'DateTools.pm';
require 'read_resources.pl';

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
    my $map_res_to_status_ref = shift;
    my $map_except_ref = shift;
    my $week = shift;

    print STDERR "DBG: find_min_resource_type cw${week} $type except: $except_1 $except_2\n";


    if( not exists $map_res_to_status_ref->{$type} )
    {
        print "FATAL: cannot find resource type $type\n";       # DBG
        exit
    }

    my $stat_ref = $map_res_to_status_ref->{$type};

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
    my( $res_1, $res_2, $res_3, $prev_duty ) = @_;

    if( $res_1 eq $prev_duty )
    {
        print "ERROR: validation failed: $res_1 $prev_duty\n";
        exit;
    }

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
    my $map_res_to_status_ref = shift;
    my $map_except_ref = shift;

    my $i = shift;

    my $type_1 = shift;
    my $type_2 = shift;
    my $type_3 = shift;

    my $prev_duty = shift;


    my ( $res_1, $res_min_1 ) = find_min_resource_type( $type_1, 0, $prev_duty, 0, $map_res_to_status_ref, $map_except_ref, $i );
    check_iter_result( $res_min_1, $type_1, $i );

    my ( $res_2, $res_min_2 ) = find_min_resource_type( $type_2, $res_1, $prev_duty, 0, $map_res_to_status_ref, $map_except_ref, $i );
    check_iter_result( $res_min_2, $type_2, $i );

    my ( $res_3, $res_min_3 ) = find_min_resource_type( $type_3, $res_1, $res_2, 0, $map_res_to_status_ref, $map_except_ref, $i );

    # try to reiterate previous step
    if( $res_min_3 == -1 )
    {
        printf STDERR "DBG: trying to reiterate ***\n";

        my ( $new_res_2, $new_res_min_2 ) = find_min_resource_type( $type_2, $res_1, $prev_duty, $res_2, $map_res_to_status_ref, $map_except_ref, $i );
        check_iter_result( $new_res_min_2, $type_2, $i );

        ( $res_2, $res_min_2 ) = ( $new_res_2, $new_res_min_2 );

        ( $res_3, $res_min_3 ) = find_min_resource_type( $type_3, $res_1, $res_2, 0, $map_res_to_status_ref, $map_except_ref, $i );
        check_iter_result( $res_min_3, $type_3, $i );

    }

    return ( $res_1, $res_2, $res_3 );
}

###############################################

sub generate_plan
{
    my $year        = shift;
    my $map_res_to_status_ref = shift;
    my $map_except_ref = shift;

    my $week = shift;
    my $last_week = shift;

    my $type_1 = shift;
    my $type_2 = shift;
    my $type_3 = shift;

    my $res       = '';

    my $prev_duty = 0;

    #print "week: $type_1 $type_2 $type_3\n";
    print "week;yy1;mm1;dd1;yy2;mm2;dd2;$type_1;$type_2;$type_3;exceptions;stat1;stat2;stat3;\n";

    for( my $i = $week; $i <= $last_week; $i = $i + 1 )
    {

        my ( $res_1, $res_2, $res_3 ) = find_plan_for_week( $map_res_to_status_ref, $map_except_ref, $i, $type_1, $type_2, $type_3, $prev_duty );

        validate_results( $res_1, $res_2, $res_3, $prev_duty );

        $prev_duty = $res_3;

        $map_res_to_status_ref->{$type_1}->{$res_1}++;
        $map_res_to_status_ref->{$type_2}->{$res_2}++;
        $map_res_to_status_ref->{$type_3}->{$res_3}++;

        my @absence = get_absence_for_week( $map_except_ref, $i );

        my( $year1, $month1, $day1 ) = DateTools::get_monday_of_week( $i, $year );
        my( $year2, $month2, $day2 ) = DateTools::get_sunday_of_week( $i, $year );

        #print "$i: $res_1 $res_2 $res_3 absence: @absence ---- $map_res_to_status_ref->{$type_1}->{$res_1} $map_res_to_status_ref->{$type_2}->{$res_2} $map_res_to_status_ref->{$type_3}->{$res_3}\n";
        #print "$i;$year1;$month1;$day1;$year2;$month2;$day2;$res_1;$res_2;$res_3;@absence;$map_res_to_status_ref->{$type_1}->{$res_1};$map_res_to_status_ref->{$type_2}->{$res_2};$map_res_to_status_ref->{$type_3}->{$res_3};\n";
        $res = $res . "$i;$year1;$month1;$day1;$year2;$month2;$day2;$res_1;$res_2;$res_3;@absence;$map_res_to_status_ref->{$type_1}->{$res_1};$map_res_to_status_ref->{$type_2}->{$res_2};$map_res_to_status_ref->{$type_3}->{$res_3};\n";
    }

    return $res;
}


###############################################

sub dump_resources
{
    my $map_res_to_status_ref = shift;

    print "\n";
    print "resources:\n";
    print "\n";

    foreach my $type ( sort keys %$map_res_to_status_ref )
    {
        print "type $type";
        foreach my $name ( sort keys %{ $map_res_to_status_ref->{$type} } )
        {
            print " $name:" . $map_res_to_status_ref->{$type}->{$name};
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
        foreach my $type ( sort keys %{ $map_except_ref->{$resu} } )
        {
            print "resource $resu: type $type:";
            foreach my $week ( sort keys %{ $map_except_ref->{$resu}->{$type} } )
            {
                print " $week";
            }
            print "\n";
        }
    }
}

###############################################

sub write_to_file
{
    my ( $filename, $str ) = @_;

    open( OUTPUT, "> $filename" )
       or die "Couldn't open file for writing: $!\n";

    print OUTPUT $str;

    close OUTPUT;
}

###############################################
sub print_help
{
    print STDERR "\nUsage: duty_planner.sh --year <year> --resources <resources.txt> --status <status.txt> [--first_week <first_week>] [--last_week <last_week>]\n";
    print STDERR "\nExamples:\n";
    print STDERR "\nduty_planner.sh --year 2018 --resources resources.txt --status status.txt\n";
    print STDERR "\nduty_planner.sh --year 2018 --resources resources.txt --status status.txt --first_week 10\n";
    print STDERR "\nduty_planner.sh --year 2018 --resources resources.txt --status status.txt --last_week 20\n";
    print STDERR "\nduty_planner.sh --year 2018 --resources resources.txt --status status.txt --first_week 10 --last_week 20\n";
    print STDERR "\n";
    exit
}
###############################################
print "duty_planner ver. $VER\n";

my $year;
my $resources;
my $status;
my $output_file = 'plan.csv';
my $verbose     = 0;

my $first_week = 1;
my $last_week  = 52;

GetOptions(
            "year=i"            => \$year,         # numeric
            "resources=s"       => \$resources,    # string
            "status=s"          => \$status,       # string
            "output=s"          => \$output_file,  # string
            "first_week:i"      => \$first_week,   # numeric
            "last_week:i"       => \$last_week,    # numeric
            "verbose"           => \$verbose   )   # flag
  or die("Error in command line arguments\n");

print STDERR "year        = $year\n";
print STDERR "resources   = $resources\n";
print STDERR "status      = $status\n";
print STDERR "output file = $output_file\n";
print STDERR "first week  = $first_week\n";
print STDERR "last week   = $last_week\n";

&print_help if not defined $year;
&print_help if not defined $resources;
&print_help if not defined $status;

my %map_res_to_status;
my %map_except;

read_resources( $resources, \%map_res_to_status, \%map_except );

read_status( $status, \%map_res_to_status );

dump_resources( \%map_res_to_status );

dump_exceptions( \%map_except );

print "\n";

my $plan = generate_plan( $year, \%map_res_to_status, \%map_except, $first_week, $last_week, 'td', '18p', 'od' );

write_to_file( $output_file, $plan );

dump_resources( \%map_res_to_status );

print "\n";

exit;


##########################
