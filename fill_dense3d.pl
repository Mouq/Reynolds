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
    #last if not defined $_;
    my $in = eval "$_"; # probably should fix this in the future
    #say STDERR  Dumper($in);
    $u->insert(map {[V($_->[0],$_->[1],$_->[2])]} @$in);
}
unless($u->positions->size){
    #say STDERR "Shelling some ideas out...";
    my $shell = 3;
    #my $shell_rad = $u->grain_radius/sin(pi/$shell);
    my $level = 0;
    my $up_by = 1;#sqrt($shell_rad**2-((2*$shell_rad**2-4*$u->grain_radius**2)/(2*$shell_rad))**2);
    #while($level*$up_by<$shell_rad){
        my $num = $shell-$level;
        my $rad = $u->grain_radius/sin(pi/$num);
        my @pos = map {V($rad * cos($_), $rad * sin($_),$level*$up_by)} map {($level/2+$_) * 2*pi/$num} 0 .. $num-1;
        say STDERR @pos;
        $u->insert(map {[$_]} @pos);
    #    $level++;
    #}
}

$SIG{'INT'} = sub {say STDERR "Whoa there! Tryin' to kill me are ya? Fine then." and exit 1};
#say join " and ", $u->sphere_intersection({centers=>[@pos], radius => 2*$u->grain_radius});
say STDERR "Up and rolling";
$u->fill_dense();

#say "*__", $u->positions->size;
#say join ",\n", map {($u->positions->at($_))=~tr/{}/[]/r} $u->positions->ordered_by_proximity;
END{ #To print even if I ctrl-c
    print "[";
    for my $i_n (0 .. $u->positions->size-1){
        print "," if $i_n;
        print STDERR "$i_n.";
        my $new = $i_n; my @surrounding = $new;
        push @surrounding, $new
            while (defined($new = $u->positions->find_nearest_neighbor(
                $u->positions->at($i_n),
                2.001*$u->grain_radius,
                map {($_=>1)} @surrounding
            )));
        print "[".(join ",",@{$u->positions->at($i_n)}, @surrounding)."]";
    }
    say "]";
}