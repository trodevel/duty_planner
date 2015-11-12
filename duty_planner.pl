#!/usr/bin/perl -w

# $Id $
# SKV FB10

# 1.0 - FB10 - initial commit

my $VER="1.0";

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

        $map_type_on_stat_ref->{$type} = \%map_stat;
        print "DBG: new resource type: " . $type . "\n";       # DBG
    }


    foreach( @wrds )
    {
#        $_ = "\u$_";
        print "DBG: type $type $_\n";       # DBG
    }
#    $a = join(" ",@wrds);

#    return $a;
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
