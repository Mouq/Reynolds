package Universe::Reynolds::3D;
our $VERSION = 0.01;

use v5.16;
use strict;
use warnings;
use autodie;
$|++;

use List::Util qw(reduce min);
use Moose;
use Carp;

use Math::BigInt;# lib => 'GMP';

use Math::Vector::Real;
use Math::Vector::Real::kdTree;
use Math::Vector::Real::Random;

use Math::Trig qw(pi spherical_to_cartesian);

use Data::Dumper;

has grain_radius => ( is => 'ro', default => sub{2.767e-18} );
has radius       => ( is => 'rw', default => sub{1e-17} );
has positions    => ( is => 'rw', default => sub { _positions_reset() } );
has velocities   => ( is => 'rw', default => sub { [] } );
has acceleration => ( is => 'rw', default => sub { [] } );
has lazy => ( is => 'rw', isa => 'Bool', default => sub{1} );
has time => ( is => 'rw', default => sub{0});
has accuracy => ( is => 'rw', default => 1e-7);

sub in_container {
    my $self      = shift;
    my $grain_pos = shift;

    # Container is just a circle
    # for now

    abs($grain_pos) + $self->grain_radius <= $self->radius ? 1 : 0;
}

sub intersection_at {
    my $self = shift;
    my $p    = shift;
    carp "Undefined point" and return unless defined($p);
    my @n = $self->positions->find_nearest_neighbor($p) or return 0;
    #return 0 if (abs(2 * $self->grain_radius - $n[1]) <= $self->accuracy);
    return 1 if ($n[1] < 2 * $self->grain_radius - $self->accuracy);
    return 0;
}

sub _positions_reset {
    Math::Vector::Real::kdTree->new(@_);
}

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
        #say('',($p=~tr/{}/[]/r),",");
        say STDERR "Given index: $i";
        push @i, $i;
    }
    return @i;
}

sub fill_dense {$|++;
    my $self = shift;
    my %checked = %{+shift//{}};
    my %done = %{+shift//{}};
    carp "Too few (".$self->positions->size.") spheres to start!" and return if $self->positions->size < 3;
    while(1){
        return if $self->positions->size == scalar %done ;
        # Start working immediately in case a file is loaded
        my $i_n = (scalar %done ? 0 : $self->positions->size-1);
        while ($i_n < $self->positions->size) {
            next if $done{$i_n};
            carp "Out of space" and return
                if volume( $self->grain_radius ) * ( $self->positions->size + 1 ) > volume( $self->radius );
            # Don't bother checking lower indicies
            my $i = $self->positions->at($i_n);
            my $changed = 0;
            my @nearest;
            my $next_nearest = sub {$self->positions->find_nearest_neighbor(
                $self->positions->at($i_n),
                4*$self->grain_radius,
                {$i_n=>1, map {($_=>1)} @nearest}
            )};
            #say "Possibilities: ", join ", ", @nearest;
            while ((my $j_n = $next_nearest->())) {
                my $j = $self->positions->at($j_n);
                for my $k_n (@nearest){
                    my $k = $self->positions->at($k_n);
                    next if $checked{join "", sort $i_n, $j_n, $k_n};
                    # Doesn't try to put anything in that isn't perfectly 'snug'
                    my @int = grep {defined} $self->sphere_intersection({
                        centers => [$i, $j, $k],
                        radius  => 2*$self->grain_radius
                    });
                    #say "Trying: $i_n, $j_n, $k_n -- ", join " - ", @int;
                    $changed += scalar @{[$self->insert(map {[$_]} @int)]} if @int;
                    $checked{join "", sort $i_n, $j_n, $k_n} = 1;
                }
                push @nearest, $j_n;
            }
            if (!$changed) {
                $done{$i_n} = 1;
                say STDERR "$i_n done"
            }
            $i_n++;
        }
    }
#    $self->fill_dense(\%checked,\%done)
}

sub sphere_intersection {
    my $self = shift;
    my @centers = @{$_[0]{centers}};
    my $radius  = $_[0]{radius};
    for my $i (0,1,2) {
        my $d = abs($centers[$i]-$centers[($i+1)%3]);
        return if !$d;
        return if $d > 2*$radius;
    }
    my $mid = ($centers[0]+$centers[1]+$centers[2])/3;
    my $perp = (($mid-$centers[0])x($mid-$centers[1]))->versor;
    #say "dist: ".abs($mid-$centers[0]);
    my $h = sqrt(abs($radius**2-(abs($mid-$centers[0]))**2));
    #say "h: $h, from $radius, ".abs($mid-$centers[0]);
    my @new = map {$perp*$_+$mid} $h, -$h;
    #say $new[1]->dist($centers[0]);
    return @new;
}


sub volume { 4 / 3 * pi * ( shift()**3 ) }

1;
