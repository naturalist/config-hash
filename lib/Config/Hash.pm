package Config::Hash;

use strict;
use warnings;
use v5.06;

use File::Basename;

our $VERSION = '0.950';

sub new {
    my ( $class, %args ) = @_;

    # Initialize defaults
    $args{data}      ||= {};
    $args{param}     ||= {};
    $args{separator} ||= qr/\./;

    my $self = bless \%args, $class;

    if ( defined $self->{filename} ) {

        # Load the main config file
        my $data = merge( $self->{data}, $self->load( $self->{filename} ) );

        # Break up the path in chunks
        my ( $name, $dir, $ext ) = fileparse( $self->{filename}, qr/\.[^.]*/ );

        # Load the rest of the files
        if ( $self->{mode} ) {
            my @modes = split( /\s*\,\s*/, $self->{mode} );
            for my $m (@modes) {
                my $filename = sprintf( "%s%s_%s%s", $dir, $name, $m, $ext );
                if ( -e $filename ) {
                    $data = merge( $data, $self->load($filename) );
                }
            }
        }

        $self->{data} = $data;
    }

    return $self;
}

sub _eval {
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

    my ( $hash, $error );
    {
        local $@;
        my $module = $filename;
        $module =~ s/\W/_/g;
        my $locals = '';

        for my $k ( keys %{ $self->param } ) {
            $locals .=
              "sub $k(); local *$k = sub { \$self->param->{'$k'} };";
        }

        my $code =
            "package Config::Hash::Sandbox::$module;"
          . "use strict;"
          . "use warnings;"
          . "sub include(\$); local *include = sub { \$self->load(\@_) };"
          . $locals
          . $text;

        $hash  = eval $code;
        $error = $@;
    }

    die "Config file $filename parse error: " . $error if $error;
    die "Config file $filename did not return a HASH - $hash"
      unless ref $hash eq 'HASH';

    return $hash;
}

sub get {
    my ( $self, $path ) = @_;
    return unless $path;
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

sub merge {
    my ( $a, $b, $sigil ) = @_;

    return $b
      if !ref($a)
      || !ref($b)
      || ref($a) ne ref($b);

    if ( ref $a eq 'ARRAY' ) {
        return $b unless $sigil;
        if ( $sigil eq '+' ) {
            for my $e (@$b) {
                push @$a, $e unless grep { eq_deeply( $_, $e ) } @$a;
            }
        }
        else {
            $a = [
                grep {
                    my $e = $_;
                    !grep { eq_deeply( $_, $e ) } @$b
                } @$a
            ];
        }
        return $a;
    }
    elsif ( ref $a eq 'HASH' ) {
        for my $k ( keys %$b ) {

            # If the key is an array then look for a merge sigil
            my $s = ref($b->{$k}) eq 'ARRAY' && $k =~ s/^(\+|\-)// ? $1 : '';

            $a->{$k} =
              exists $a->{$k}
              ? merge( $a->{$k}, $b->{"$s$k"}, $s )
              : $b->{$k};
        }

        return $a;
    }
    return $b;
}

sub data  { $_[0]->{data} }
sub param  { $_[0]->{param} }
sub DESTROY {}

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

=head1 MERGING

Config::Hash merges two hashes so that the second hash overrides the first
one. Let's say we have two hashes, A and B. Merging will proceed as follows:

=over

=item

Each key in B that doesn't contain a hash will be copied to A. Duplicate
keys will be overwriten in favor of B.

=cut

=item

Each key in B that contains a hash will be merged using the same algorithm
described here.

=cut

=back

Example:

    # Example 1
    $a      = { a => 1, b => 2 };
    $b      = { a => 3 };
    $merged = { a => 2, b => 2 };

    # Example 2
    $a      = { a => { b => 'foo' } };
    $b      = { a => { b => 'baz' }, c => 'bar' };
    $merged = { a => { b => 'baz', c => 'bar' } };    # Hashes merge

    # Example 3:
    $a      = { a => [ 1, 2, 3 ] };
    $b      = { a => [] };
    $merged = { a => [] };            # Non-hashes overwrite the other key

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


Each key of the C<param> hash can be accessed via a function with the same name
inside the config file:

    # app.conf

    {
        name => 'Rick James',
        path => base_path() . 'rick/james'
    };

The evaluation of the config code is isolated from the rest of the code, so
it doesn't have access to C<$self>. If you need to use C<$self>, you'll have
to pass it in the C<params> hash and then reference it with C<self()>

B<Note:> You will have to add C<()> to the function name, otherwise Perl will
not recognize it as such and will die with an error.

=head2 separator

A regular expression for the value separator used by L</get>. The default is
C<qr/\./>, i.e. a dot.

=head1 SUBROUTINES

=head2 get

Get a value from the config hash.

    my $value = $c->get('bar.foo.baz');
    my $same  = $c->get('bar')->{foo}->{baz};
    my $again = $c->data->{bar}->{foo}->{baz};

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
