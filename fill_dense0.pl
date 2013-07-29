#!/usr/bin/env perl -w
use strict;
use v5.16;
$|++;

use Data::Dumper;

my $accuracy = 20;
#use Math::BigFloat;
#use Math::Big qw{ sin cos };
use bignum  ( p => -20 );
use Universe::Reynolds;
use Math::Trig qw{pi};
use Math::Vector::Real;

my $u = Universe::Reynolds->new(
    radius          => 5.0,
    grain_radius    => 1.0
);  # number of spheres  radius**3 / grain_radius**3

my $num = 5;
my $rad = $u->grain_radius/sin(pi/$num);
my @pos = map {V($rad * cos($_), $rad * sin($_), 0)} map {$_ * 2*pi/$num} 0 .. $num-1;
#say "$rad ", join " and ", @pos;
#say 2*$u->grain_radius - abs($pos[0]-$pos[1]);
$u->insert(map {[$_]} @pos);
#say "__", $u->positions->size;

#say join " and ", $u->sphere_intersection({centers=>[@pos], radius => 2*$u->grain_radius});
$u->fill_dense();

#say "*__", $u->positions->size;
#say join ",\n", map {($u->positions->at($_))=~tr/{}/[]/r} $u->positions->ordered_by_proximity;