package Universe::Reynolds;
our $VERSION = 0.01;

use v5.16;
use strict;
use warnings;
use autodie;
$|++;

use Moose;
use Carp;

use Math::BigInt;# lib => 'GMP';

use Math::Vector::Real;
use Math::Trig qw(pi spherical_to_cartesian);

use Math::Vector::Real::Random;

use Data::Dumper;    ##

# Modified kdTree implementation
# (In same dir as Universe/)
use lib ".";
use Math::Vector::Real::kdTree;

has grain_radius => ( is => 'ro', isa => 'Num', default => 2.767e-18 );
has radius       => ( is => 'rw', isa => 'Num', default => 1e-17 );
has positions  => ( is => 'rw', default => sub { _positions_reset() } );
has velocities => ( is => 'rw', default => sub { [] } );
has lazy => ( is => 'rw', isa => 'Bool', default => 1 );

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
    $n[1] < 2 * $self->grain_radius;

}

sub _positions_reset {
    Math::Vector::Real::kdTree->new(@_);
}

sub step {
    my $self    = shift;
    my $step_by = shift or croak "Bad time interval supplied";
    my $next_in = $self->next_collision_in;
    if ( $step_by < $next_in ) {
        for ($#{$self->velocities}) {
            next unless $self->velocities->[$_];
            $self->positions->move($_, $self->positions->at($_) + $self->velocities->[$_] * $step_by);
        }
        $self->next_collision_in( -$step_by ); # Next collision happens in $step_by less time
    }
    else {
        $self->collide;
        $self->step( $step_by - $next_in );
    }
}

sub insert {
    my $self = shift;
    my @i;
    for (@_) {
        my ( $p, $v ) = @$_;
        map { bless $_, 'Math::Vector::Real' } $p, $v;
        carp "Grain attempted to be placed out of bounds" and next
          if not $self->in_container($p);
        carp "Grain attempted to be placed intersecting another grain" and next
          if $self->intersection_at($p);
        my $i = $self->positions->insert($p);
        $self->velocities->[$i] = $v // V( 0, 0, 0 );
        push @i, $i;
    }
    return @i;
}

sub next_collision_in {
    my $self = shift;
    state $next_in;
    my $move_by = shift;
    if ( defined $move_by ) {
        $next_in += $move_by;
    }
    else {
        $next_in = 1;
        #  $self->lazy ? $self->next_collision_partial : $self->next_collision;
    }
}

sub next_collision {

    # O(n^2)
    my $self     = shift;
    my @n_c      = ( Math::BigInt->binf, undef, undef );
    my @to_check = 0 .. $self->positions->size;
    while (@to_check) {
        my $i = pop @to_check;
        for (@to_check) {
            next
              unless abs( $self->velocities->[$i] - $self->velocities->[$_] );
            my $t = $self->grains_touch_in( $i, $_ );
            @n_c = ( $t, $i, $_ ) if $t < $n_c[0];
            push @n_c, ( $t, $i, $_ ) if $t == $n_c[0];
        }
        my $t = $self->touches_wall_in($i);
        @n_c = ( $t, $i, $_ ) if $t < $n_c[0];
        push @n_c, ( $t, $i, undef ) if $t == $n_c[0];
    }
    return \@n_c;
}

sub next_collision_partial {

    # O(n)
    my $self = shift;
    my @n_c = ( Math::BigInt->binf, undef, undef );
    for my $i ( 0 .. $self->positions->size ) {
        my @nearest = $self->surrounding_spheres($i);
        for (@nearest) {
            next
              unless abs( $self->velocities->[$i] - $self->velocities->[$_] );
            my $t = $self->grains_touch_in( $i, $_ );
            @n_c = ( $t, $i, $_ ) if $t < $n_c[0];
            push @n_c, ( $t, $i, $_ ) if $t == $n_c[0];
        }
        next unless abs( $self->velocities->[$i] );
        my $t = $self->touches_wall_in($i);
        @n_c = ( $t, $i, $_ ) if $t < $n_c[0];
        push @n_c, ( $t, $i, undef ) if $t == $n_c[0];
    }
    return \@n_c;
}

sub surrounding_spheres {
    my $self = shift;
    my $i = shift;
    my @nearest;
    for ( 1 .. 12 ) {
        push @nearest,
          $self->positions->find_nearest_neighbor( $self->positions->at($i),
          undef, \@nearest );
    }
    return @nearest;
}

sub circle_circle_intersection {
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
    # Blatently stolen: http://stackoverflow.com/a/3349134
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
    my @t = map { $_ * ( ($r // 0) / abs($v) ) + ( $p / $v ) } 1, -1;
    $t[0] > 0
      && $t[0] >= $t[1] ? $t[0] : $t[1] > 0 ? $t[1] : Math::BitInt->binf;
}

sub volume { 4 / 3 * pi * ( shift()**3 ) }

## Fill methods

sub fill_random_path {
    my $self = shift;
    my $percent_fill = shift;
    my $start = shift // V(0,0,0);
    return if ( volume( $self->grain_radius ) * ( $self->positions->size + 1 ) <=
                volume( $self->radius ) * $percent_fill );
    my $i = $self->insert( [ $start, V( 0, 0, 0 ) ] );
    
    # Find where we _can't_ put a sphere
    my $angle_xz = rand(2*pi);
    my @nearby     = $self->surrounding_spheres($i);
    my $c0 = $self->positions->at($i);
    my @kiss_points;
    for my $s_i (@nearby) {
        my $c1 = $self->positions->at($i);
        next if abs($c1-$c0) > 4*$self->radius;
        my $r1 = sqrt($self->radius**2 + ($c0->[0]+$c1->[0])*(cos($angle_xz) - $c0->[0] - $c1->[0])
                                       + ($c0->[1]+$c1->[1])*(sin($angle_xz) - $c0->[1] - $c1->[1]));
        push @kiss_points, [
            circle_circle_intersection(
                V(0,0), # Somewhat dubious ATM
                $self->radius,
                V( ($c0->[0]+$c1->[0])*cos($angle_xz)
                  +($c0->[1]+$c1->[1])*sin($angle_xz),
                $c1->[2])
            )];
    }
    my @range = (0, 2*pi); # Start, stop, start, ...
    for (@kiss_points) {
        # Transform into angle
        # Add to @range
        my ($ang_begin, $ang_end) = map { atan2($_->[0], $_->[1]) } $_->[0], $_->[1];
        next unless $ang_begin - $ang_end;
        ($ang_begin, $ang_end) = ($ang_end, $ang_begin) if $ang_end + $ang_begin > pi;
        my ($a, $b);
        for (0 .. $#range-1) { # Perhaps not the best way
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
    croak "Bug" if (@range % 2);
    my $total;
    for (0 .. int $#range/2) {
        $total += $range[$_+1] -$range[$_];
    }
    my $angle_y = rand($total);
    for (0 .. int $#range/2) {
        last if $angle_y < $range[$_+1];
        $angle_y += $range[$_+2] - $range[$_+1] if $angle_y >= $range[$_+1];
    }
    fill_random_path($percent_fill, V(spherical_to_cartesian(2*$self->radius, $angle_xz, $angle_y)));
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

1;

