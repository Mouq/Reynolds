#!usr/bin/env perl -w
use Wx;

package MyFrame;
use base 'Wx::Frame';
use v5.16;
use Universe::Reynolds;
use Math::Trig qw(pi);
use Math::Vector::Real;
use bignum;

my $u = Universe::Reynolds->new(
    grain_radius => .001,
    radius       => 1
);
$u->fill_random_path(.90, &{ sub {
    V( $_[0]*cos($_[1])*cos($_[2]),
       $_[0]*sin($_[1])*cos($_[2]),
       $_[0]*sin($_[1])
    )} }(rand($u->radius - $u->grain_radius), rand(2*pi), rand(2*pi)) );

sub new {
    my $ref = shift;
    my $self = $ref->SUPER::new(
        undef,
        -1,
        'Universe::Reynolds',
        [-1, -1],
        [-1, -1] # Change as fit
    );
    my $dc = Wx::MemoryDC::new($self);
    my $p = Wx::Pen::new('blue', 4);
    $dc->SetPen($p);
    $dc->DrawCircle(4,4, 50);

    $self;
}

package Universe::Reynolds::Visualize::Wx;
use base 'Wx::App';

sub OnInit {
    my $frame = MyFrame->new;
    $frame->Show(1);
}

package main;

my $app = Universe::Reynolds::Visualize::Wx->new; #verbosity or what

$app->MainLoop;
