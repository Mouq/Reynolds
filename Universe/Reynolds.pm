package Universe::Reynolds;
our $VERSION = 0.01;

use strict;
use warnings;
use autodie;
$|++;

use Moose;
use Carp;

use Math::Vector::Real;
use Math::Vector::Real::kdTree;
use Math::Trig qw(pi);

use Math::Vector::Real::Random;

has grain_radius => ( is => 'ro', isa => 'Num', default => 2.767e-18 );
has radius       => ( is => 'rw', isa => 'Num', default => 1e-17 );
has positions =>
  ( is => 'rw', default => sub { Math::Vector::Real::kdTree->new } );
has velocities => ( is => 'rw', default => sub { [] } );

sub in_container {
    my $self  = shift;
    my $grain = shift;

    # Container is just a sphere
    # for now

    abs($grain) + $self->grain_radius > $self->radius ? 0 : 1;
}

sub intersection_at {
    my $self = shift;
    my $p    = shift;
    carp "Undefined point" and return unless defined($p);
    my $n = $self->positions->find_nearest_neighbor($p) or return 0;
    $n->[1] < 2 * $self->grain_radius;
}

sub fill_random {
    my $self = shift;
    my $percent_fill = shift // 1 - 1e-5;
    $self->positions(
        Math::Vector::Real::kdTree->new(
            Math::Vector::Real->random_in_sphere(
                3, $self->radius - $self->grain_radius
            )
        )
    );

    while ( volume( $self->grain_radius ) * ( $self->positions->size + 1 ) <
        volume( $self->radius ) * $percent_fill )
    {
        my $tmp = Math::Vector::Real->random_in_sphere( 3,
            $self->radius - $self->grain_radius );

        $self->insert( [ $tmp, V( 0, 0, 0 ) ] )
          unless $self->intersection_at($tmp);
    }
}

sub step {
    my $self    = shift;
    my $step_by = shift;
    ...;
}

sub insert {
    my $self = shift;
    for (@_) {
        my ( $p, $v ) = @$_;
        carp "Grain attempted to be inserted out of bounds" && next
          if $self->in_container($p);
        carp "Grain attempted to be placed intersecting another grain" && next
          if $self->intersection_at($p);
        my $i = $self->positions->insert($p);
        $self->velocities->[$i] = $v;
    }
}

sub next_collision {
    ...;
}

sub probably_next_collision {
    ...;
}

sub volume { 4 / 3 * pi * ( shift()**3 ) }

1;

