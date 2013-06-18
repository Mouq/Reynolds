use Test::More tests => 8;
use Test::Warn;

use Math::Vector::Real;
use Universe::Reynolds;

my $u = Universe::Reynolds->new;

isa_ok( $u, 'Universe::Reynolds' );

can_ok( $u, qw(step next_collision) );

$u = Universe::Reynolds->new( grain_radius => 1, radius => 1 );
$u->fill_random(.90);

is( $u->positions->size, 0 );

$u = Universe::Reynolds->new( grain_radius => 1, radius => 2 );
eval {
    $u->insert( [ [ 0, 0, 1 ], [ 0, 0, 0 ] ], [ [ 0, 0, -1 ], [ 0, 0, 0 ] ] );
};

is( $u->positions->size, 2 );

$u = Universe::Reynolds->new( grain_radius => 1, radius => 2 );
warning_like {
    $u->insert( [ [ 0, 0, 1 ], [ 0, 0, 0 ] ], [ [ 0, 0, -1.5 ], [ 0, 0, 0 ] ] );
}
qr[out of bounds];

is( $u->positions->size, 1 );

$u = Universe::Reynolds->new( grain_radius => .04, radius => 1 );
ok( $u->fill_random(.25) );
{
    my $x = $u;
    $x->step(.5);
    is( $u->positions, $x->positions );
}
