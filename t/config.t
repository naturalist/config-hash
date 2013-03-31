
use strict;
use warnings;

use Test::More tests => 33;
use Test::Deep;
use Test::Exception;
use Config::Hash;
use FindBin '$Bin';

my $data = {
    a => 1,
    b => 2,
    c => $Bin,
    d => { e => 3 },
    f => { g => { h => { i => 4 } } }
};

my $file = "$Bin/bin/test.conf";
my %args = ( filename => $file, param => { bin => $Bin } );
my $c    = Config::Hash->new(%args);

isa_ok $c, 'Config::Hash';

# Basic access
is_deeply $c->data, $data;

is $c->get('a'),       1;
is $c->get('d.e'),     3;
is $c->get('f.g.h.i'), 4;
is_deeply $c->get('f.g.h'), { i => 4 };
is $c->get(''), undef;
is $c->get(), undef;

# Get breaks
dies_ok { $c->get('b.c') } "Path breaks";

# Data only
{
    my $d = Config::Hash->new( data => $c->data );
    cmp_deeply $d->data, $c->data;
    is $d->get('f.g.h.i'), 4;
}

# Data, extended with a file
{
    my $added = { init => 'yes' };
    my $d = Config::Hash->new( %args, data => $added );

    cmp_deeply $d->data, superhashof($added);
    cmp_deeply $d->data, superhashof($data);

    is $d->get('init'),    'yes';
    is $d->get('f.g.h.i'), 4;
}

# Separator
{
    my $d = Config::Hash->new(
        separator => qr/\-/,
        data    => $c->data
    );
    is $d->get('f-g-h-i'), 4;
}

# Parse error
dies_ok { Config::Hash->new( filename => "$Bin/bin/test_bad.conf" ) }
"Dies on syntax errors";

# No hash returned
dies_ok { Config::Hash->new( filename => "$Bin/bin/test_bad2.conf" ) }
"Dies if no hash returned";

# Using $self error
dies_ok { Config::Hash->new( filename => "$Bin/bin/test_bad3.conf" ) }
"Dies when \$self is referenced";

# Try a missing param
dies_ok { Config::Hash->new( filename => "$Bin/bin/test_bad4.conf" ) }
"Dies when a missing param is used";


# Merge 1
{
    my $d = Config::Hash->new( %args, mode => 'merge' );
    is $d->get('merged'), 'indeed';
    is $d->get('a'),      'new';
    is $d->get('second'), undef;
}

# Merge 2
{
    my $d = Config::Hash->new( %args, mode => 'merge, merge2' );
    is $d->get('merged'), 'indeed';
    is $d->get('a'),      'new';
    is $d->get('second'), 'present';
}

# Merge with missing
{
    my $d = Config::Hash->new( %args, mode => 'merge, merge2, missing' );
    is $d->get('merged'), 'indeed';
    is $d->get('a'),      'new';
    is $d->get('second'), 'present';
}

# Params
{
    my $d = Config::Hash->new(
        filename => "$Bin/bin/test_param.conf",
        param    => {
            bar => 'foo',
            foo => 'baz',
            hash => {data => {a => 1}}
        }
    );

    is $d->get('bar'), 'foo';
    is $d->get('foo'), 'baz';
    is $d->get('data.a'), 1;

}

# Load a missing file
$SIG{__WARN__} = sub {};
is_deeply $c->load('missing'), {};
