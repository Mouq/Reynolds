#!usr/bin/env perl
use strict;
use warnings;
use autodie;
$|++;

use OpenGL qw( :all );

use Universe::Reynolds;

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
