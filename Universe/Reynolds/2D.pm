package Universe::Reynolds::2D;
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
    return 0 if (abs(2 * $self->grain_radius - $n[1]) < $self->accuracy);
    return ($n[1] < 2 * $self->grain_radius);
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
        say('',($p=~tr/{}/[]/r),",");
        #say "Given index: $i";
        push @i, $i;
    }
    return @i;
}

sub fill_dense {$|++;
    my $self = shift;
    my %checked = %{+shift//{}};
    my %done = %{+shift//{}};
    carp "Too few (".$self->positions->size.") spheres to start!" and return if $self->positions->size < 2;
    carp "Out of space" and return
        if area( $self->grain_radius ) * ( $self->positions->size + 1 ) > area( $self->radius );
    return if $self->positions->size ==  keys %done ;
    # Doesn't try to put anything in that isn't perfectly 'snug'
    for my $i_n (grep {!$done{$_}} 0 .. $self->positions->size-1) {
        # Don't bother checking lower indicies
        my $i = $self->positions->at($i_n);
        my %checked_old = %checked;
        my @nearest;
        my $next_nearest = sub {$self->positions->find_nearest_neighbor(
            $self->positions->at($i_n),
            4*$self->grain_radius,
            {$i_n=>1, map {($_=>1)} @nearest}
        )};
        #say "Possibilities: ", join ", ", @nearest;
        while ((my $j_n = $next_nearest->())) {
            push @nearest, $j_n;
            my $j = $self->positions->at($j_n);
            next if $checked{join "", sort $i_n, $j_n};
            my @int = grep {defined} $self->circle_intersection({
                centers => [$i, $j],
                radius  => 2*$self->grain_radius
            });
            #say "Trying: $i_n, $j_n -- ", join " - ", @int;
            $self->insert(map {[$_]} @int) if @int;
            $checked{join "", sort $i_n, $j_n} = 1;
        }
        $done{$i_n} = 1 if (%checked_old ~~ %checked);
    }
    $self->fill_dense(\%checked,\%done)
}

sub circle_intersection {
    my $self = shift;
    my @centers = @{$_[0]{centers}};
    my $radius  = $_[0]{radius};
    my $d = abs($centers[0]-$centers[1]);
    return if !$d;
    return if $d > 2*$radius;
    my $mid = ($centers[0]+$centers[1])/2;
    my $perp = V(-($mid-$centers[0])->[1],($mid-$centers[0])->[0])->versor;
    #say "dist: ".abs($mid-$centers[0]);
    my $h = sqrt(abs($radius**2-(abs($mid-$centers[0]))**2));
    #say "h: $h, from $radius, ".abs($mid-$centers[0]);
    my @new = map {$perp*$_+$mid} $h, -$h;
    #say $new[1]->dist($centers[0]);
    return @new;
}

sub area {
    pi*$_[0]**2
}

1;
