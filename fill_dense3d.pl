#!/usr/bin/env perl -w
use strict;
use v5.16;
$|++;

use Data::Dumper;

my $accuracy = 20;
#use Math::BigFloat;
#use Math::Big qw{ sin cos };
#use bignum  ( p => -20 );
use Universe::Reynolds::3D;
use Math::Trig qw{pi};
use Math::Vector::Real;

my $u = Universe::Reynolds::3D->new(
    radius          => 50.0,
    grain_radius    => 1.0
);  # number of spheres = O(radius**2 / grain_radius**2)

while(<>){
    my $in = eval "[$_]"; # probably should fix this in the future
    #say Dumper($in);
    $u->insert(map {[V($_->[0],$_->[1],$_->[2])]} @$in);
}
unless($u->positions->size){
    my $num = 3;
    my $rad = $u->grain_radius/sin(pi/$num);
    my @pos = map {V($rad * cos($_), $rad * sin($_),0)} map {$_ * 2*pi/$num} 0 .. $num-1;
    #say "$rad ", join " and ", @pos;
    #say 2*$u->grain_radius - abs($pos[0]-$pos[1]);
    $u->insert(map {[$_]} @pos);
    #say "__", $u->positions->size;
}{
    my $num = 8;
    my $rad = $u->grain_radius/sin(pi/$num);
    my @pos = map {V($rad * cos($_), $rad * sin($_),0)+V(40,20,3)} map {$_ * 2*pi/$num} 0 .. $num-1;
    #say "$rad ", join " and ", @pos;
    #say 2*$u->grain_radius - abs($pos[0]-$pos[1]);
#    $u->insert(map {[$_]} @pos);
    #say "__", $u->positions->size;
}

$SIG{'INT'} = sub {say STDERR "Whoa there! Tryin' to kill me are ya? Fine then." and exit 1};
#say join " and ", $u->sphere_intersection({centers=>[@pos], radius => 2*$u->grain_radius});
say STDERR "Up and rolling";
$u->fill_dense();

#say "*__", $u->positions->size;
#say join ",\n", map {($u->positions->at($_))=~tr/{}/[]/r} $u->positions->ordered_by_proximity;
END{ #To print even if I ctrl-c
    say "[";
    for my $i_n (0 .. $u->positions->size-1){
        print "," if $i_n;
        my $new = $i_n; my @surrounding = $new;
        push @surrounding, $new
            while (defined($new = $u->positions->find_nearest_neighbor(
                $u->positions->at($i_n),
                3*$u->grain_radius,
                map {($_=>1)} @surrounding
            )));
        print "[".(join ",",@{$u->positions->at($i_n)}, scalar @surrounding)."]";
    }
    say "]";
}