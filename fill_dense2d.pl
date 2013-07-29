#!/usr/bin/env perl -w
use strict;
use v5.16;
$|++;

use Data::Dumper;

my $accuracy = 20;
#use Math::BigFloat;
#use Math::Big qw{ sin cos };
#use bignum  ( p => -20 );
use Universe::Reynolds::2D;
use Math::Trig qw{pi};
use Math::Vector::Real;

my $u = Universe::Reynolds::2D->new(
    radius          => 100.0,
    grain_radius    => 1.0
);  # number of spheres ~ radius**2 / grain_radius**2
{
    my $num = 7;
    my $rad = $u->grain_radius/sin(pi/$num);
    my @pos = map {V($rad * cos($_), $rad * sin($_))} map {$_ * 2*pi/$num} 0 .. $num-1;
    #say "$rad ", join " and ", @pos;
    #say 2*$u->grain_radius - abs($pos[0]-$pos[1]);
    $u->insert(map {[$_]} @pos);
    #say "__", $u->positions->size;
}{
    my $num = 9;
    my $rad = $u->grain_radius/sin(pi/$num);
    my @pos = map {V($rad * cos($_), $rad * sin($_))+V(40,20)} map {$_ * 2*pi/$num} 0 .. $num-1;
    #say "$rad ", join " and ", @pos;
    #say 2*$u->grain_radius - abs($pos[0]-$pos[1]);
    $u->insert(map {[$_]} @pos);
    #say "__", $u->positions->size;
}

#say join " and ", $u->sphere_intersection({centers=>[@pos], radius => 2*$u->grain_radius});
$u->fill_dense();

#say "*__", $u->positions->size;
#say join ",\n", map {($u->positions->at($_))=~tr/{}/[]/r} $u->positions->ordered_by_proximity;