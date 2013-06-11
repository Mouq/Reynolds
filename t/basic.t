use Test::More tests => 4;
use Test::Exception;

use Universe::Reynolds;

my $u = Universe::Reynolds->new;

isa_ok( $u, 'Universe::Reynolds' );

can_ok( $u, qw(step next_collision) );

$u = Universe::Reynolds->new( grain_radius => 1, radius => 1 );
$u->fill_random(1);

is( $u->positions->size, 1 );

$u = Universe::Reynolds->new( grain_radius => 1, radius => 2 );
eval {
    $u->insert( [ [ 0, 0, 1 ], [ 0, 0, 0 ] ], [ [ 0, 0, -1 ], [ 0, 0, 0 ] ] );
};

is( $u->positions->size, 2 );
__END__
$u = Universe::Reynolds->new( grain_radius => 1, radius => 2 );
eval{ $u->insert([ [0,0,1], [0,0,0] ], [ [0,0,-1.5], [0,0,0] ]) };

like( $@, qr[out of bounds]);

is( $u->positions->size, 1);

