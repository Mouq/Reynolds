package Universe::Reynolds;
our $VERSION = 0.01;

use v5.16;
use strict;
use warnings;
use autodie;
$|++;

use Moose;
use Carp;

use Math::BigInt lib => 'GMP';

use Math::Vector::Real;
use Math::Trig qw(pi);

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

sub fill_random {
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

sub step {
    my $self    = shift;
    my $step_by = shift;
    my $next_in = $self->next_collision_in;
    if ( $step_by < $next_in ) {

        # move each
        $self->next_collision_in( +$step_by );
    }
    else {
        $self->collide;
        $self->step( $step_by - $next_in );
    }
}

sub insert {
    my $self = shift;
    for (@_) {
        my ( $p, $v ) = @$_;
        map { bless $_, 'Math::Vector::Real' } $p, $v;
        carp "Grain attempted to be placed out of bounds" and next
          if not $self->in_container($p);
        carp "Grain attempted to be placed intersecting another grain" and next
          if $self->intersection_at($p);
        my $i = $self->positions->insert($p);
        $self->velocities->[$i] = $v // V( 0, 0, 0 );
    }
}

sub next_collision_in {
    my $self = shift;
    state $next_in;
    my $move_by = shift;
    if ( defined $move_by ) {
        $next_in -= $move_by;
    }
    else {
        $next_in =
          $self->lazy ? $self->next_collision_partial : $self->next_collision;
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
        my @nearest;
        for ( 1 .. 12 ) {
            push @nearest,
              $self->positions->find_nearest_neighbor( $self->positions->at($i),
                undef, \@nearest );
        }
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
    my @t = map { $_ * ( $r / abs($v) ) + ( $p / $v ) } 1, -1;
    $t[0] > 0
      && $t[0] >= $t[1] ? $t[0] : $t[1] > 0 ? $t[1] : Math::BitInt->binf;
}

sub volume { 4 / 3 * pi * ( shift()**3 ) }

1;

