#!usr/bin/env perl
use strict;
use warnings;
use autodie;
$|++;

use OpenGL qw( :all );
use Math::Vector::Real;
use Math::Vector::Real::kdTree;
use Math::Trig qw(pi);

use Math::Vector::Real::Random;

### Abstractions

# A sphere is an object
# with a position V(x,y,z)
# and constant radius:
my $R = 2.767e-18;

# Size of simulation
my $outerR = shift(@ARGV) // 1e-17;    #5e-17;

# proportion of space to fill
my $pFill = shift(@ARGV) // 1 - 1e-5;

# Comfortable kd-Tree home
# for our new round family
my $S = genSpheres();
print $S->size;

sub inContainer {

    # Container is just a sphere
    # for now

    abs(shift) + $R > $outerR
      ? return 0
      : return 1;
}

sub genSpheres {
    my $space =
      Math::Vector::Real::kdTree->new(
        Math::Vector::Real->random_in_sphere( 3, $outerR - $R ) );

    while ( volume($R) * ( $space->size + 1 ) < volume($outerR) * $pFill ) {
        my $tmp = Math::Vector::Real->random_in_sphere( 3, $outerR - $R );
        unless ( [ $space->find_nearest_neighbor($tmp) ]->[1] < 2 * $R ) {
            $space->insert($tmp);
        }
    }

    return $space;
}

sub volume {
    return 4 / 3 * pi * ( shift()**3 );
}

### Visualizations

glutInit();

my ( $Window_Width, $Window_Height ) = ( 500, 500 );

sub drawInit {
    my $points = shift;

    my $wID = glutCreateWindow("Sphere simulation");
    cbResizeScene( $Window_Width, $Window_Height );

    # Change this if no significant preformance diff
    glShadeModel(GL_FLAT);

    glClearColor( 0.1, 0.1, 0.1, 0.0 );
}

sub cbResizeScene {
    my ( $Width, $Height ) = @_;

    # Let's not core dump, no matter what.
    $Height = 1 if ( $Height == 0 );

    glViewport( 0, 0, $Width, $Height );

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective( 45.0, $Width / $Height, 0.1, 100.0 );

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    $Window_Width  = $Width;
    $Window_Height = $Height;
}
