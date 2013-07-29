package Universe::Reynolds;
our $VERSION = 0.02;

use v5.16;
use strict;
use warnings;
use autodie;
$|++;

=head1 NAME

Universe::Reynolds

=head1 SYNOPSIS

    use Universe::Reynolds;
    
    my $u = Universe::Reynolds->new(
        grain_radius => 1,
        radius       => 1000
    );
    
    $u->fill_random;
    # fill_dense is recommended when implemented

    $u->step(1) while 1;

=head1 DESCRIPTION

A module to simulate a ton of densly packed spheres in a container
(currently implemented as a large sphere itself), as the late Osborne
Reynolds postulated our universe to be. There may, in the future, be
methods to also analyze the density, or really the inverse density, of
the system.

=cut

use List::Util qw(reduce min);
use Moose;
use Carp;

use Math::BigInt;# lib => 'GMP';

use Math::Vector::Real;
use Math::Vector::Real::kdTree;
use Math::Vector::Real::Random;

use Math::Trig qw(pi spherical_to_cartesian);

use Data::Dumper;

=head1 CONSTRUCTOR

=over 4

=item new( [ARGS] )

Configure any of the key-value pairs:
    grain_radius
    radius
    lazy # Bool, trades sureness for speed

=back

=cut

has grain_radius => ( is => 'ro', default => sub{2.767e-18} );
has radius       => ( is => 'rw', default => sub{1e-17} );
has positions    => ( is => 'rw', default => sub { _positions_reset() } );
has velocities   => ( is => 'rw', default => sub { [] } );
has acceleration => ( is => 'rw', default => sub { [] } );
has lazy => ( is => 'rw', isa => 'Bool', default => sub{1} );
has time => ( is => 'rw', default => sub{0});
has accuracy => ( is => 'rw', default => 1e-7);

=head1 METHODS

=over 4

=cut

sub in_container {
    my $self      = shift;
    my $grain_pos = shift;

    # Container is just a sphere
    # for now

    abs($grain_pos) + $self->grain_radius <= $self->radius ? 1 : 0;
}

sub intersection_at {
    my $self = shift;
    my $p    = shift;
    carp "Undefined point" and return unless defined($p);
    my @n = $self->positions->find_nearest_neighbor($p) or return 0;
    #return $n[1] < 2 * $self->grain_radius
    #say "Testing intersection: ", abs( $self->positions->at($n[0])-$p ), " < ", 2 * $self->grain_radius, " is ", (abs( $self->positions->at($n[0])-$p ) < 2 * $self->grain_radius)?'true':'false';
    return 0 if (abs(2 * $self->grain_radius - $n[1]) < $self->accuracy);
    return ($n[1] < 2 * $self->grain_radius);
}

sub _positions_reset {
    Math::Vector::Real::kdTree->new(@_);
}

=item insert( [ pos, vel, acc  ], ... )

Try to place new sphere(s) into the universe at position = [x,y,z],
velocity = [x,y,z], and acceleration = [x,y,z], all defaulting to
[0,0,0]

=cut

sub insert {
    my $self = shift;
    my $no_warnings = 1;#pop if !ref($_[$#_]);
    my @i;
    for my $new (@_) {
        my ($p, $v, $a);
        map {$_ = (bless( (shift(@$new) // [0,0,0]), 'Math::Vector::Real')) } $p, $v, $a;
        #say "Inserting: $p, $v, $a";
        ($no_warnings || carp("Grain ($p) attempted to be placed out of bounds by from line ".(caller)[2]) ) and next
          if not $self->in_container($p);
        ($no_warnings || carp("Grain ($p) attempted to be placed intersecting another grain from line ".(caller)[2]) ) and next
          if $self->intersection_at($p);
        my $i = $self->positions->insert($p);
        $self->velocities->[$i] = $v // V( 0, 0, 0 );
        say('',($p=~tr/{}/[]/r),",");
        #say "Given index: $i";
        push @i, $i;
    }
    return @i;
}

=item step( $step_by )

Move the simulation forward by time interval $step_by

=cut

sub step {
    my $self    = shift;
    my $step_by = shift // croak "No time interval supplied";
    return 1 if $step_by==0;
    my $next_in = $self->next_collision_in;
    if (not defined $next_in) {
        $self->lazy ? $self->next_collision_partial : $self->next_collision;
        $next_in = $self->next_collision_in;
    }
    say "Next in: $next_in";
    if ( $step_by < $next_in ) {
        $self->move( $step_by );
        $self->next_collision_in( -$step_by ); # Next collision happens in $step_by less time
        $self->time( $self->time + $step_by );
    }
    else {
        $self->collide;
        $self->lazy ? $self->next_collision_partial : $self->next_collision;
        $self->time( $self->time + $next_in );
        $self->step( $step_by - $next_in );
    }
}

sub move {
    my $self = shift;
    my $step_by = shift || return 1;
    my $i = 0;
    while ($i < @{$self->velocities}) {
        next unless $self->velocities->[$i];
        $self->positions->move($i, $self->positions->at($i) + $self->velocities->[$i] * $step_by);
        $i++
    }
}

{   # Collision scope

    # Array of arrays of the soonest (simultaneous) collisions
    state @n_c;
    # that all happen at time:
    state $t;

    sub next_collision_in {
        # Accessor, basically
        return $t+=$_[1] if defined $_[1];
        return $t;
    }

    sub next_collision {
        # O(n^2)
        my $self     = shift;
        my $i = 0;
        while ($i < $self->positions->size) {
            my $j = $i; # Triangular counting
            while ($j < $self->positions->size) {
                next unless abs( $self->velocities->[$i] - $self->velocities->[$_] );
                my $t_new = $self->grains_touch_in( $i, $_ );
                if ( (not defined $t) || $t_new < $t ) {
                    $t = $t_new;
                    @n_c = [$i, $j];
                } elsif ( $t_new == $t ) {
                    push @n_c, [$i, $j];
                }
                $j++
            }
            next unless abs( $self->velocities->[$i] );
            my $t_new = $self->touches_wall_in($i);
            if ( (not defined $t) || $t_new < $t ) {
                $t = $t_new;
                @n_c = [$i, undef];
            } elsif ( $t_new == $t ) {
                push @n_c, [$i, undef];
            }
            $i++
        }
        return \@n_c;
    }

    sub next_collision_partial {
        # O(n)
        my $self = shift;
        my $i = 0;
        while ($i < $self->positions->size) {
            my @nearest = $self->surrounding_spheres($i);
            for (@nearest) {
                next unless abs( $self->velocities->[$i] - $self->velocities->[$_] );
                my $t_new = $self->grains_touch_in( $i, $_ );
                if ( (not defined $t) || $t_new < $t ) {
                    $t = $t_new;
                    @n_c = [$i, $_];
                } elsif ( $t_new == $t ) {
                    push @n_c, [$i, $_];
                }
                ($t = $t_new) and (@n_c = [$i, $_] ) if (not defined $t) || $t_new < $t;
                push @n_c, [$i, $_] if $t_new == $t;
            }
            next unless abs( $self->velocities->[$i] );
            my $t_new = $self->touches_wall_in($i);
            if ( (not defined $t) || $t_new < $t ) {
                $t = $t_new;
                @n_c = [$i, undef];
            } elsif ( $t_new == $t ) {
                push @n_c, [$i, undef];
            }
            $i++;
        }
        return \@n_c;
    }

    sub collide {
        my $self = shift;
        $self->move($t);
        my(@wall, @rest);
        map {defined($_->[1]) ? push @rest, $_ : push @wall, $_->[0]} @n_c;
        for (@wall) {
            my $v = $self->velocities->[$_];
            my $p = $self->positions->at($_);
            # I think this could be reduced
            $self->velocities->[$_] = $v - 2*($v*$p)/abs($p)*($p->versor);
        }
        for (@rest) {
            ...

        }
    }

}

sub surrounding_spheres {
    my $self = shift;
    my $i = shift;
    my $d = shift; #max distance
    my %nearest;
    $nearest{$i} = (@_ ? shift : 1); #don't count same point as input (default true)
    for ( 1 .. 12 ) {
        my $k =
        $self->positions->find_nearest_neighbor(
            $self->positions->at($i),
            $d,
            \%nearest
        );
        $nearest{$k} = 1 if defined $k
    }
    return keys %nearest;
}

sub circle_circle_intersection { ## rename to circle_intersection() 
    my ($center1, $radius1, $center2, $radius2) = @_;
    # centers assumed to be V()s
    my $d = abs($center1-$center2);
    return if $d > $radius1+$radius2 or
              $d < abs($radius1-$radius2) or
              !($d || $radius1-$radius2);
    my $a = ($radius1**2 - $radius2**2 + $d**2)/(2*$d);
    return $a unless $d - $radius1 - $radius2;
    my $h = $radius1**2 - $a**2;
    my $mid = $center1 + $a * ( $center2 - $center1 ) / $d;
    return map {V( $center1->[0] + $_*($center2->[1] - $center1->[1])/$d,
                   $center1->[1] - $_*($center2->[0] - $center1->[0])/$d )} $h, -$h;
    # Blatently stolen from: http://stackoverflow.com/a/3349134
}

sub sphere_intersection { ## Makes some assumptions, *s\h\o\u\l\d\* w\o\r\k\...
    ## Nope, _terrible_ assumptions. Need to rework from scratch.
    ## It'll be easier just to
    die;
    ## for now.

    my $self = shift;
    my @centers = @{$_[0]{centers}};
    #say "CENTERS\t@centers";
    my $radius  = $_[0]{radius}; # Assumption for now
    my $avg     = (reduce {$a+$b} @centers)/3;
    #my $cross   = (V(map {Math::BigFloat->new($_)} @{$avg-$centers[0]}))x(V(map {Math::BigFloat->new($_)} @{$avg-$centers[1]}));
    my $cross   = ($avg-$centers[0])x($avg-$centers[1]);
    #say "AVG $avg\tCROSS\t$cross";
    return unless abs($cross);
    (0 <= ($radius**2-(abs($avg-$_))**2) || return) for @centers;
    my @x = map {
        $_ * sqrt( ($radius**2-(abs($avg-$centers[0]))**2) / (abs( $cross ))**2 )
    } +1, -1;
    @x = map { my $x = $_;
        V(map {$_*$x} @$cross) + $avg
    } @x;
    ( ($x[0]->dist($_) - 2*$radius < $self->accuracy && $x[1]->dist($_) - 2*$radius < $self->accuracy) || return) for @centers;
    return @x;
}

sub grains_touch_in {
    my $self = shift;
    my ( $a, $b ) = @_;
    my $v = $self->velocities->[$a] - $self->velocities->[$b];
    my $p = $self->positions->at($a) - $self->positions->at($b);
    _touch_in( $p, $v, 2 * $self->grain_radius );
}

sub touches_wall_in {
    my $self = shift;
    my $a    = shift;
    my $v    = $self->velocities->[$a];
    my $p    = $self->positions->at($a);
    _touch_in( $p, $v, $self->grain_radius + $self->radius );
}

sub _touch_in {
    my ( $p, $v, $r ) = @_;
    return Math::BigInt->binf if !abs($v);
    my @t = map { $_ * ( ($r // 0) / abs($v) ) + ( $v * $p / ($v*$v) ) } 1, -1;
    say "Touch in: @t";
    return min grep {$_ > 0} @t
}

sub volume { 4 / 3 * pi * ( shift()**3 ) }

## Fill methods

=item fill_random( $percent_filled )

Puts spheres where there aren't spheres until the universe is filled
as close as possible to the requested $percent_filled

=cut

sub fill_dense { #_simple ## Sloppy
    my $self = shift;
    my %checked = %{+shift//{}};
    my %done = %{+shift//{}};
    carp "Too few (".$self->positions->size.") spheres to start!" and return if $self->positions->size < 3;
    carp "Out of space" and return if volume( $self->grain_radius ) * ( $self->positions->size + 1 ) >
                                      volume( $self->radius );
    return if $self->positions->size ==  keys %done ;
    # Doesn't try to put anything in that isn't perfectly 'snug'
    for my $i_n (grep {!$done{$_}} 0 .. $self->positions->size-1) {
        # Don't bother checking lower indicies
        my $i = $self->positions->at($i_n);
        my %checked_old = %checked;
        my @nearest = sort(($self->positions->size < 1000) ? grep {abs($self->positions->at($_)-$i)<=4*$self->grain_radius
                              && abs($self->positions->at($_)-$i)}  $self->positions->ordered_by_proximity : $self->surrounding_spheres($i_n));
        #say "Possibilities: ", join ", ", @nearest;
        for my $j_n (@nearest) {
            my $j = $self->positions->at($j_n);
            for my $k_n (grep {$_ > $j_n} @nearest) {
                my $k = $self->positions->at($k_n);
                next if $checked{join "", sort $i_n, $j_n, $k_n};
                my @int = grep {defined} $self->sphere_intersection({
                    centers => [($i, $j, $k)],
                    radius  => 2*$self->grain_radius
                });
                #say "Trying: $i_n, $j_n, $k_n -- ", join " - ", @int;
                $self->insert(map {[$_]} @int) if @int;
                $checked{join "", sort $i_n, $j_n, $k_n} = 1;
            }
        }
        $done{$i_n} = 1 if (%checked_old ~~ %checked);
    }
    $self->fill_dense(\%checked,\%done)
}

sub fill_random {
    # This is a non-trivial caclulation
    my $self = shift;
    my $percent_fill = shift;
    my $ang1 = rand(2*pi);
    my $ang2 = rand(2*pi);
    for (0 .. $self->positions->size-1) {
        #my $p = $i
        ...
    }
}

sub fill_random_path { #Broken :(
    my $self = shift;
    my $percent_fill = shift;
    my $start = shift // V(0,0,0);
    my($i) = $self->insert( [ $start, V( 0, 0, 0 ) ] );
    
    # Find where we _can't_ put a sphere
    my $angle_xz = rand(2*pi);
    my $c0       = $self->positions->at($i);
    my @nearby   = $self->surrounding_spheres($i);
    my @kiss_points;
    say "@nearby";
    for my $s_i (@nearby) {
        my $c1 = $self->positions->at($s_i);
        next if ($c0 == $c1);
        next if abs($c1-$c0) > 4*$self->grain_radius;
        my $r1sq = $self->grain_radius**2
                 + ($c0->[0]+$c1->[0])*(cos($angle_xz) - $c0->[0] - $c1->[0])
                 + ($c0->[1]+$c1->[1])*(sin($angle_xz) - $c0->[1] - $c1->[1]);
        next if $r1sq<0;
        my $r1 = sqrt($r1sq);
        push @kiss_points, [
            circle_circle_intersection(
                V(0,0), # Somewhat dubious ATM
                $self->grain_radius,
                V( ($c0->[0]+$c1->[0])*cos($angle_xz)
                  +($c0->[1]+$c1->[1])*sin($angle_xz),
                  $c1->[2]),
                $r1
            )];
    }

    my @border_case = circle_circle_intersection(
        V(0,0),
        $self->grain_radius,
        V( $c0->[0]*cos($angle_xz) + $c0->[1]*sin($angle_xz), 0 ),
        $self->radius
    );

    my @range = (0, 2*pi); # Start, stop, start, ...
    for (@kiss_points) {
        # Transform into angle
        # Add to @range
        say "::@$_";
        my ($ang_begin, $ang_end) = map { atan2($_->[0], $_->[1]) } $_->[0], $_->[1];
        next unless $ang_begin - $ang_end;
        ($ang_begin, $ang_end) = ($ang_end, $ang_begin) if $ang_end + $ang_begin > pi;
        my ($a, $b);
        for (0 .. $#range-1) { # The following should be a general function
            my ($p, $n) = @range[$_,$_+1];
            $a = $_ if !defined($a) && $p <= $ang_begin && $ang_begin <= $n;
            $b = $_ if !defined($b) && $p <= $ang_end   && $ang_end   <= $n;
            last if defined $a and defined $b;
        }
        if ($a==$b and !($a % 2)) {
            @range = ( splice( @range, 0, $a ), $ang_begin, $ang_end, splice( @range, $a+1) );
        } elsif ($a > $b) {
            @range = ( ($b % 2 ? () : $ang_end) , splice( @range, $b+1, $a ), ($a % 2 ? () : $ang_begin) );
        } else {
            @range = ( splice( @range, 0, $a ), ($a % 2 ? () : $ang_begin), ($b % 2 ? () : $ang_end), splice( @range, $b+1 ) );
        }
    }

    { 
        my ($a, $b);
        for (0 .. $#range-1) {
            my ($p, $n) = @range[$_,$_+1];
            $a = $_ if !defined($a) && $p <= $border_case[0] && $border_case[0] <= $n;
            $b = $_ if !defined($b) && $p <= $border_case[1] && $border_case[1] <= $n;
            last if defined $a and defined $b;
        }
        if ($a==$b and !($a % 2)) {
            @range = (
                splice( @range, 0, $a ),
                $border_case[0],
                $border_case[1],
                splice( @range, $a+1)
            );
        } elsif ($a > $b) {
            @range = (
                ($b % 2 ? () : $border_case[1]),
                splice( @range, $b+1, $a ),
                ($a % 2 ? () : $border_case[0])
            );
        } else {
            @range = (
                splice( @range, 0, $a ),
                ($a % 2 ? () : $border_case[0]),
                ($b % 2 ? () : $border_case[1]),
                splice( @range, $b+1 )
            );
        }
    }
    my $total;
    for (0 .. int $#range/2) {
        $total += $range[$_+1] -$range[$_];
    }
    return if !$total;
    my $angle_y = rand($total);
    for (0 .. int $#range/2) {
        last if $angle_y < $range[$_+1];
        $angle_y += $range[$_+2] - $range[$_+1] if $angle_y >= $range[$_+1];
    }
    
    while ( volume( $self->grain_radius ) * ( $self->positions->size + 1 ) <=
            volume( $self->radius ) * $percent_fill )
    {
        my $coords = V(spherical_to_cartesian(2*$self->grain_radius, $angle_xz, $angle_y));
        say "(($coords))";
        $self->fill_random_path(
            $percent_fill,
            $coords
        );
    }
    return "triumphant!";
}

sub fill_random_stupid {
    my $self = shift;
    my $percent_fill = shift // 1 - 1e-5;

    while ( volume( $self->grain_radius ) * ( $self->positions->size + 1 ) <=
            volume( $self->radius ) * $percent_fill )
    {
        # print $self->positions->size,"\n";
        # can take some time .. implement looser, more effecient method

        my $tmp = Math::Vector::Real->random_in_sphere( 3,
            $self->radius - $self->grain_radius );

        $self->insert( [ $tmp, V( 0, 0, 0 ) ] )
          unless $self->intersection_at($tmp)
          or not $self->in_container($tmp);
    }
    $self;
}

=back

=cut

1;

