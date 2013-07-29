#!usr/bin/env perl
use v5.16;
use Carp;
$|++;

use lib "..";
use Universe::Reynolds;
my $u = Universe::Reynolds->new(
    radius => 100,
    grain_radius => 1,
);
my $step_by = 0;
$u->insert(
    [ [0,0,0],      [1,0,0] ],
    #[ [20, 13, 15], [3,-1,-6] ]
);

use IO::Socket;
my $socket = new IO::Socket::INET(
    LocalAddr => 'localhost',
    LocalPort => 5050,
    Listen    => 1,
    Reuse     => 1,
    Proto     => 'tcp',
) or croak "No socket created!";

my $latest;
while ( $latest = $socket->accept() ){
    my $request = <$latest>;
    $request =~ m!(?:GET|POST) /(.*) HTTP/1..!
        or carp("Bad request: $request") && next;
    my %api_req = (map {$_=~/(.*)=(.*)/?($1=>$2):($_=>1)} split /\+/, $1)
        or carp("Bad api call: $1") && next;
    #say  $latest "$_ => $api_req{$_}" for keys %api_req;
    say $latest "<step time=".$u->time." >";
    say $latest "<positions>"
                . (join " ", @{$u->positions->{vs}})
                . "</positions>"
        if $api_req{pos} or $api_req{positions};
    say $latest "<velocities>"
                . (join " ", @{$u->velocities})
                . "</velocities>"
        if $api_req{vel} or $api_req{velocities};
    say $latest "</step>";
    $step_by = 0+$api_req{time} if $api_req{time};
    close $latest;
    $u->step($step_by);
}
close $socket;
