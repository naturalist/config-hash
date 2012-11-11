package Config::Hash;

use strict;
use warnings;
use v5.06;

use File::Basename;
use Hash::Merge;

our $VERSION = '0.913';

sub new {
    my ( $class, %args ) = @_;

    # Initialize defaults
    $args{data}      ||= {};
    $args{param}     ||= {};
    $args{separator} ||= qr/\./;

    my $self = bless \%args, $class;

    if ( defined $self->{filename} ) {

        Hash::Merge::set_behavior('RIGHT_PRECEDENT');

        # Load the main config file
        my $data =
          Hash::Merge::merge( $self->{data},
            $self->load( $self->{filename} ) );

        # Break up the path in chunks
        my ( $name, $dir, $ext ) = fileparse( $self->{filename}, qr/\.[^.]*/ );

        # Load the rest of the files
        if ( $self->{mode} ) {
            my @modes = split( /\s*\,\s*/, $self->{mode} );
            for my $m (@modes) {
                my $filename = sprintf( "%s%s_%s%s", $dir, $name, $m, $ext );
                if ( -e $filename ) {
                    $data =
                      Hash::Merge::merge( $data, $self->load($filename) );
                }
            }
        }

        $self->{data} = $data;
    }

    return $self;
}

sub _eval {
    my $p = shift;
    local $@;
    return (eval shift, $@);
}

sub load {
    my ( $self, $filename ) = @_;

    # Open and read file
    open( my $in, "<:encoding(UTF-8)", $filename )
      or do {
        warn "Can not read config file " . $filename;
        return {};
      };

    my $text = do { local $/ = undef; <$in> };
    close($in);

    my ( $hash, $error ) = _eval( $self->param, $text );
    die "Config file $filename parse error: " . $error if $error;
    die "Config file $filename did not return a HASH"
      unless ref $hash eq 'HASH';

    return $hash;
}

sub get {
    my ( $self, $path ) = @_;
    my @a = split( $self->{separator}, $path );
    my $val = $self->{data};
    for my $chunk (@a) {
        if ( ref($val) eq 'HASH' ) {
            $val = $val->{$chunk};
        }
        else {
            die "Config path $path breaks at '$chunk'";
        }
    }
    return $val;
}

sub param { $_[0]->{param} }
sub data  { $_[0]->{data} }

1;

__END__

=head1 NAME

Config::Hash

=head1 DESCRIPTION

Handle config files containing Perl hashes

=head1 SYNOPSIS

Read, parse and merge config files containing Perl hashes:

    my $c = Config::Hash->new( filename => 'MyApp.conf' );
    my $user = $c->get('mysql.test.user');
    my $pass = $c->get('mysql.test.pass');

    # The contents of the config file named MyApp.conf:
    # {
    #   mysql => {
    #       test => {
    #           user => 'rick',
    #           pass => 'james'
    #       }
    #   }
    # };

Manually initialize the config data:

    my $c = Config::Hash->new(
        data => {
            user => 'james',
            pass => 'rick',
            ips  => {
                alpha => '127.0.0.1',
                beta  => '10.0.0.2'
            }
          }
    );

    say "Beta is at: " . $c->get('ips.beta');

Merge data with config files:

    my $c = Config::Hash->new(
        data => { server => 'localhost' },
        filename => 'MyApp.conf'
    );

In this case the contents of the file will merge with the data hash, with
precedent given to the config file.

=head1 DESCRIPTION

Simple yet powerful config module. Why simple? Because it uses Perl hashes.
Why powerful? Because it uses Perl hashes.

=head1 ATTRIBUTES

=head2 filename

Full pathname of the config file.

    my $c = Config::Hash->new( filename => 'conf/stuff.pl' );

It does not matter what file extension is used, as long as the file contains a
legitimate Perl hash. Example:

    # conf/stuff.pl
    {
        redis => 1,
        mongo => {
            table => 'stuff',
            data  => 'general'
        }
    };

=head2 data

Load a Perl hash instead of a file.

    my $c = Config::Hash->new(
        data => {
            redis => 1,
            mysql => {
                user => 'test',
                pass => 'secret'
            }
        }
    );

=head2 mode

Application mode or modes. Files that match the modes will be merged into
the configuration data. Example:

    my $c = Config::Hash->new(
        filename => 'app.conf',
        mode     => 'development'
    );

This will look first for a file C<app.conf>, then for C<app_development.conf>
and both files will be merged.
C<mode> can be a comma separated list of modes, so:

    my $c = Config::Hash->new(
        filename => 'app.conf',
        mode     => 'development, local, test'
    );

will look for and merge C<app.conf>, C<app_development.conf>,
C<app_local.conf> and C<app_test.conf>.

=head2 param

Allows for passing variables to the config hash.

    my $c = Config::Hash->new(
        filename => 'app.conf',
        param    => { base_path => '/path/to/stuff' }
    );


Param is initialized as a variable C<$p> inside the config file, so it could
be accessed this way:

    # app.conf

    {
        name => 'Rick James',
        path => $p->{base_path} . 'rick/james'
    };

The evaluation of the config code is isolated from the rest of the code, so
it doesn't have access to C<$self>. If you need to use C<$self>, you'll have
to pass it in the C<params> hash and then reference it with C<$p-E<gt>{self}>

=head2 separator

A regular expression for the value separator used by L</get>. The default is
C<qr/\./>, i.e. a dot.

=head1 SUBROUTINES

=head2 get

Get a value from the config hash.

    my $value = $c->get('bar.foo.baz');
    my $same  = $c->get('bar')->{foo}->{baz};
    my $again = $c->hash->{bar}->{foo}->{baz};

By default the subhash separator is a dot, but this can be changed via the
L</separator> attribute.

    my $c = Config::Hash->new(
        filename  => 'app.conf',
        separator => qr/\-/
    );

    my $value = $c->get('bar-foo-baz');

=head1 AUTHOR

minimalist - minimal@cpan.org

=head1 LICENSE

Same as Perl itself.

=cut
