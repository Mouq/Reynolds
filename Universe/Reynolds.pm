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

# A sphere is an object
# with a position V(x,y,z)
# and constant radius:
has sphere_r => (is => 'ro', isa => 'Num', default => 2.767e-18);

# Size of simulation
has universe_r => (is => 'ro', isa => 'Num', default => 1e-17); #5e-17

# Comfortable kd-Tree home
# for our new round family
has universe => (is => 'rw');

sub in_container {
    my $self = shift;
    my $sphere = shift;

    # Container is just a sphere
    # for now

    abs($sphere) + $self->sphere_r > $self->universe_r ? 0 : 1;
}

sub fill_random {
    my $self = shift;
    my $percent_fill = shift // 1 - 1e-5;
    $self->universe = Math::Vector::Real::kdTree->new(
        Math::Vector::Real->random_in_sphere( 3, $self->universe_r - $self->sphere_r )
    );

    while ( volume($self->sphere_r) * ( $self->universe->size + 1 )
          < volume($self->universe_r) * $self->percent_fill )
    {
        my $tmp = Math::Vector::Real->random_in_sphere( 3, $self->universe_r - $self->sphere_r );
        $self->universe->insert($tmp) unless
            [ $self->universe->find_nearest_neighbor($tmp) ]->[1] < 2 * $self->sphere_r ;
    }

    1;
}

sub step {
    my $self = shift;
    my $step_by = shift;
    ...
}

sub next_collision {
    ...
}

sub probably_next_collision {
    ...
}

sub volume {
    return 4 / 3 * pi * ( shift()**3 );
}

1;


