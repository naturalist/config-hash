
use strict;
use warnings;

use Test::More tests => 15;
use Config::Hash;
use FindBin '$Bin';

my $file = "$Bin/bin/test.conf";
my $c = Config::Hash->new( filename => $file, param => { bin => $Bin } );

# Basic access
is_deeply $c->data, {
    a => 1,
    b => 2,
    c => $Bin,
    d => { e => 3 },
    f => { g => { h => { i => 4 } } }
  };

is $c->get('a'),       1;
is $c->get('d.e'),     3;
is $c->get('f.g.h.i'), 4;
is_deeply $c->get('f.g.h'), { i => 4 };

# Data only
{
    my $d = Config::Hash->new( data => $c->data );
    is_deeply $d->data, $c->data;
    is $d->get('f.g.h.i'), 4;
}

# Data, extended with files
{
    my $d = Config::Hash->new(
        data     => { init => 'yes' },
        filename => $file
    );

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
{
    eval {
        Config::Hash->new( filename => "$Bin/bin/test_bad.conf" );
    };
    ok $@, "Dies on syntax errors";
}

# Parse error
{
    eval {
        Config::Hash->new( filename => "$Bin/bin/test_bad2.conf" );
    };
    ok $@, "Dies if no hash returned";
}

# Using $self error
{
    eval {
        Config::Hash->new( filename => "$Bin/bin/test_bad3.conf" );
    };
    ok $@, "Dies when \$self is referenced";
}

# Merge
{
    my $d = Config::Hash->new(
        filename => $file,
        mode     => 'merge'
    );
    is $d->get('merged'), 'indeed';
    is $d->get('a'),      'new';
}

