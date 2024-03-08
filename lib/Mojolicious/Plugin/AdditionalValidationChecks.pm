package Mojolicious::Plugin::AdditionalValidationChecks;

# ABSTRACT: Add additional validation checks

use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '0.18';

use Email::Valid;
use Scalar::Util qw(looks_like_number);
use Time::Piece;
use Mojo::URL;

sub register {
    my ($self, $app) = @_;

    my $email = Email::Valid->new(
        allow_ip => 1,
    );

    my $validator = $app->validator;
    $validator->add_check( email => sub {
        my ($self, $field, $value, @params) = @_;
        my $address = $email->address( @params, -address => $value );
        return $address ? 0 : 1;
    });

    $validator->add_check( int => sub {
        my ($nr) = $_[2] =~ m{\A ([\+-]? [0-9]+) \z}x;
        my $return = defined $nr ? 0 : 1;
        return $return;
    });

    $validator->add_check( min => sub {
        return 1 if !looks_like_number( $_[2] );
        return if !length $_[3];
        return $_[2] < $_[3];
    });

    $validator->add_check( max => sub {
        return 1 if !looks_like_number( $_[2] );
        return if !length $_[3];
        return $_[2] > $_[3];
    });

    $validator->add_check( phone => sub {
        return 0 if $_[2] =~ m{\A
            ((?: \+ | 00 ) [1-9]{1}[0-9]{0,2})? # country
            \s*? [0-9]{2,5} \s*?      # local
            [/-]?
            \s*? [0-9]{2,12}          # phone
        \z}x;
        return 1;
    });

    $validator->add_check( length => sub {
        my ($self, $field, $value, $min, $max) = @_;

        my $length = length $value;

        return 0 if !$min && !$max;

        return 1 if $min && $length < $min;
        return 1 if $max && $length > $max;

        return 0;
    });

    $validator->add_check( http_url => sub {
        my $url = Mojo::URL->new( $_[2] );
        return 1 if !$url->is_abs;
        return 1 if !grep{ $url->scheme eq $_ }qw(http https);
        return 0;
    });

    $validator->add_check( not => sub {
        my ($validation, @tmp) = (shift, shift, shift);
        return 0 if !@_;

        my $field = $validation->topic;
        $validation->in( @_ );

        if ( $validation->has_error($field) ) {
            delete $validation->{error}->{$field};
            return 0;
        }

        return 1;
    });

    $validator->add_check( color => sub {
        my ($validation, $field, $value, $type) = @_;

        state $rgb_int = qr{
            \s* (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | [1-9][0-9] | [0-9] )
        }x;

        state $rgb_percent = qr{
            \s* (?: 100 | [1-9][0-9] | [0-9] ) \%
        }x;

        state $alpha = qr{
            \s* (?: 0 | 0?\.[0-9]+ | 1(?:\.0)? )
        }x;

        state $types = {
            rgb  => qr{
                \A
                    rgb\(
                        (?:
                            (?:
                                (?:$rgb_int,){2} $rgb_int
                            ) |
                            (?:
                                (?:$rgb_percent,){2} $rgb_percent
                            )    
                        )    
                    \)
                \z
            }x,
            rgba  => qr{
                \A
                    rgba\(
                        (?:
                            (?:
                                (?:$rgb_int,){3} $alpha
                            ) |
                            (?:
                                (?:$rgb_percent,){3} $alpha
                            )    
                        )    
                    \)
                \z
            }xms,
            hex  => qr{
                \A
                    \#
                    (?: (?:[0-9A-Fa-f]){3} ){1,2}
                \z
            }xms,
            hsl  => qr{
                \A
                    hsla?\(
                        (?:
                            -? [0-9]+ \s* (?:deg|g?rad|turn)?
                            (?<sep>[, ]) \s*
                            $rgb_percent \g{sep} \s*
                            $rgb_percent \s*
                            (?:
                                (?(?{$+{sep} eq ','}) , | / ) \s*
                                (?:$alpha|$rgb_percent)
                            )?
                        )    
                    \)
                \z
            }xms,

        };

        return 1 if !$types->{$type};

        my $found = $value =~ $types->{$type};
        return !$found;
    });

    $validator->add_check( uuid => sub {
        my ($validation, $field, $value, $type) = @_;

        my %regexes = (
            3   => qr/\A[0-9A-F]{8}-[0-9A-F]{4}-3[0-9A-F]{3}-[0-9A-F]{4}-[0-9A-F]{12}\z/i,
            4   => qr/\A[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}\z/i,
            5   => qr/\A[0-9A-F]{8}-[0-9A-F]{4}-5[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}\z/i,
            all => qr/\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\z/i,
        );

        $type ||= 'all';
        my $regex = $regexes{$type};
        $regex    = $regexes{all} if !$regex;

        return $value !~ $regex;
    });

    $validator->add_check( hex => sub {
        my ($validation, $field, $value, $type) = @_;

        return $value !~ m{\A [0-9A-Fa-f]+ \z}xms;
    });

    $validator->add_check( float => sub {
        my ($validation, $field, $value) = @_;

        return $value !~ m{
            \A
                (?:
                    [+-]?
                    (?:[0-9]+)
                )?
                (?:
                    \.
                    [0-9]*
                )
                (?:
                    [eE]
                    [\+\-]?
                    (?:[0-9]+)
                )?
            \z
        }xms;
    });

    $validator->add_check( ip => sub {
        my ($validation, $field, $value, $type) = @_;

        $type //= 4;

        state $octett = qr{
            (?: 25[0-5] | 2[0-4][0-9] | 1[0-9][0-9] | [1-9][0-9] | [0-9] )
        }xms;

        my $ipv4 = "((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))";
        my $g    = "[0-9a-fA-F]{1,4}";
        
        my @tail = (
            ":",
            "(:($g)?|$ipv4)",
            ":($ipv4|$g(:$g)?|)",
            "(:$ipv4|:$g(:$ipv4|(:$g){0,2})|:)",
            "((:$g){0,2}(:$ipv4|(:$g){1,2})|:)",
            "((:$g){0,3}(:$ipv4|(:$g){1,2})|:)",
            "((:$g){0,4}(:$ipv4|(:$g){1,2})|:)",
        );
        
        my $ipv6 = $g;
        $ipv6 = "$g:($ipv6|$_)" for @tail;
        $ipv6 = qq/:(:$g){0,5}((:$g){1,2}|:$ipv4)|$ipv6/;
        $ipv6 =~ s/\(/(?:/g;

        my %regexes = (
            4 => qr/\A (?: $octett \. ){3} $octett \z/xms,
            6 => qr/\A$ipv6\z/,
        );

        my $regex = $regexes{$type};
        $regex    = $regexes{4} if !$regex;

        return $value !~ $regex;
    });

    $validator->add_check( between => sub {
        my $op = (looks_like_number( $_[3] ) and looks_like_number( $_[4] ) ) ? 'n' : 's';

        my $result;
        if ( $op eq 'n' ) {
            $result = $_[2] < $_[3] || $_[2] > $_[4];
        }
        else {
            $result = (
                ( ( $_[2] cmp $_[3] ) == -1 ) ||
                ( ( $_[4] cmp $_[2] ) == -1 )
            );
        }

        return $result;
    });

    $validator->add_check( number => sub {
        my ($validation, @tmp) = (shift, shift, shift);

        return 1 if !looks_like_number( $tmp[1] );

        my $field = $validation->topic;
        $validation->check( 'int', $tmp[1] );

        return 0 if !$validation->has_error($field);

        $validation->output->{$field} = $tmp[1];
        delete $validation->{error}->{$field};

        $validation->check( 'float', $tmp[1] );

        return 0 if !$validation->has_error($field);

        delete $validation->{error}->{$field};
 
        return 1;
    });

    $validator->add_check( date => sub {
        return 1 if !$_[2];
        return 1 if $_[2] !~ m{\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z};

        my $date;
        eval {
            $date = Time::Piece->strptime( $_[2], '%Y-%m-%d' );
            1;
        } or return 1;

        # this is needed as 2013-02-31 is parsed, but will return 2013-03-03 for ymd()
        return 1 if $_[2] ne $date->ymd;

        return 0;
    });
}

1;
__END__

=encoding utf8

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('AdditionalValidationChecks');

  # Controller
  my $validation = $self->validation;
  $validation->input({ nr => 3 });
  $validation->required( 'nr' )->max( 10 );

or more realistically, validating a parameter from the URL query string:

  use Mojolicious::Lite -signatures;

  # Load the plugin
  plugin 'AdditionalValidationChecks';

  # Route leading to a validation check
  any '/' => sub ($c) {
      # Extract 'nr' from the query string, default to 0 if not provided
      my $nr = $c->param('nr') // 0;

      my $validation = $c->validation;
      $validation->input({ nr => $nr });
      $validation->required('nr')->max(10);
      if ($validation->is_valid) {
          $c->render(text => "Number is valid.");
      } else {
          $c->render(text => "Number is not valid.");
      }
  };

  app->start;

=head1 DESCRIPTION

L<Mojolicious::Plugin::AdditionalValidationChecks> adds a few validation checks to
the L<Mojolicious validator|Mojolicious::Validator>.

=head1 NOTE

The behaviour of empty strings changed in L<Mojolicious 8.34|https://github.com/mojolicious/mojo/blob/v8.34/Changes>.
So e.g. this was valid before 8.34 and is now invalid:

  my $validation = $self->validation;
  $validation->input({ nr => '' });
  $validation->required( 'nr' )->phone();

=head1 CHECKS

These checks are added:

=head2 email

Checks that the given value is a valid email. It uses C<Email::Valid>.

=head3 simple check

This does only check whether the given mailaddress is valid or not

  my $validation = $self->validation;
  $validation->input({ email_address => 'dummy@test.example' });
  $validation->required( 'email_address' )->email();

=head3 check also MX

Check if there's a mail host for it

  my $validation = $self->validation;
  $validation->input({ email_address => 'dummy@test.example' });
  $validation->required( 'email_address' )->email(-mxcheck => 1);

=head2 phone

Checks if the given value is a phone number:

  my $validation = $self->validation;
  $validation->input({ nr => '+49 123 / 1321352' });
  $validation->required( 'nr' )->phone(); # valid
  $validation->input({ nr => '00 123 / 1321352' });
  $validation->required( 'nr' )->phone(); # valid
  $validation->input({ nr => '0123 / 1321352' });
  $validation->required( 'nr' )->phone(); # valid

=head2 min

Checks a number for a minimum value. If a non-number is passed, it's always invalid

  my $validation = $self->validation;
  $validation->input({ nr => 3 });
  $validation->required( 'nr' )->min( 10 ); # not valid
  $validation->required( 'nr' )->min( 2 );  # valid
  $validation->input({ nr => 'abc' });
  $validation->required( 'nr' )->min( 10 ); # not valid

=head2 max

Checks a number for a maximum value. If a non-number is passed, it's always invalid

  my $validation = $self->validation;
  $validation->input({ nr => 3 });
  $validation->required( 'nr' )->max( 10 ); # not valid
  $validation->required( 'nr' )->max( 2 );  # valid
  $validation->input({ nr => 'abc' });
  $validation->required( 'nr' )->max( 10 ); # not valid

=head2 length

In contrast to the C<size> "built-in", this check also allows to
omit the maximum length.

  my $validation = $self->validation;
  $validation->input({ word => 'abcde' });
  $validation->required( 'word' )->length( 2, 5 ); # valid
  $validation->required( 'word' )->length( 2 );  # valid
  $validation->required( 'word' )->length( 8, 10 ); # not valid

=head2 int

Checks if a number is an integer. If a non-number is passed, it's always invalid

  my $validation = $self->validation;
  $validation->input({ nr => 3 });
  $validation->required( 'nr' )->int(); # valid
  $validation->input({ nr => 'abc' });
  $validation->required( 'nr' )->int(); # not valid
  $validation->input({ nr => '3.0' });
  $validation->required( 'nr' )->int(); # not valid

=head2 http_url

Checks if a given string is an B<absolute> URL with I<http> or I<https> scheme.

  my $validation = $self->validation;
  $validation->input({ url => 'http://perl-services.de' });
  $validation->required( 'url' )->http_url(); # valid
  $validation->input({ url => 'https://metacpan.org' });
  $validation->required( 'url' )->http_url(); # valid
  $validation->input({ url => 3 });
  $validation->required( 'url' )->http_url(); # not valid
  $validation->input({ url => 'mailto:dummy@example.com' });
  $validation->required( 'url' )->http_url(); # not valid

=head2 not

The opposite of C<in>.

  my $validation = $self->validation;
  $validation->input({ id => '3' });
  $validation->required( 'id' )->not( 2, 5 ); # valid
  $validation->required( 'id' )->not( 2 );  # valid
  $validation->required( 'id' )->not( 3, 8, 10 ); # not valid
  $validation->required( 'id' )->not( 3 );  # not valid

=head2 color

Checks if the given value is a "color". There are three flavours of
colors:

=over 4

=item * rgb

  my $validation = $self->validation;
  $validation->input({ color => 'rgb(11,22,33)' });
  $validation->required( 'color' )->color( 'rgb' ); # valid
  $validation->input({ color => 'rgb(11, 22, 33)' });
  $validation->required( 'color' )->color( 'rgb' ); # valid
  $validation->input({ color => 'rgb(11%,22%,33%)' });
  $validation->required( 'color' )->color( 'rgb' ); # valid
  $validation->input({ color => 'rgb(11%, 22%, 33%)' });
  $validation->required( 'color' )->color( 'rgb' ); # valid

=item * rgba

  my $validation = $self->validation;
  $validation->input({ color => 'rgba(11,22,33,0)' });
  $validation->required( 'color' )->color( 'rgba' ); # valid
  $validation->input({ color => 'rgb(11, 22, 33,0.0)' });
  $validation->required( 'color' )->color( 'rgba' ); # valid
  $validation->input({ color => 'rgb(11, 22, 33,0.6)' });
  $validation->required( 'color' )->color( 'rgba' ); # valid
  $validation->input({ color => 'rgb(11%,22%,33%, 1)' });
  $validation->required( 'color' )->color( 'rgba' ); # valid
  $validation->input({ color => 'rgb(11%, 22%, 33%, 1.0)' });
  $validation->required( 'color' )->color( 'rgba' ); # valid

=item * hex

  my $validation = $self->validation;
  $validation->input({ color => '#afe' });
  $validation->required( 'color' )->color( 'hex' ); # valid
  $validation->input({ color => '#affe12' });
  $validation->required( 'color' )->color( 'hex' ); # valid

=back

=head2 uuid

As there are different variants of UUIDs, you can check for
those variants

=over 4

=item * uuid - all

This is the default variant

  my $validation = $self->validation;
  $validation->input({ uuid => 'A987FBC9-4BED-3078-CF07-9141BA07C9F3' });
  $validation->required( 'uuid' )->uuid();        # valid
  $validation->required( 'uuid' )->uuid( 'all' ); # valid

=item * variant 3

  my $validation = $self->validation;
  $validation->input({ uuid => 'A987FBC9-4BED-3078-CF07-9141BA07C9F3' });
  $validation->required( 'uuid' )->uuid( 3 ); # valid

=item * variant 4

  my $validation = $self->validation;
  $validation->input({ uuid => '713ae7e3-cb32-45f9-adcb-7c4fa86b90c1' });
  $validation->required( 'uuid' )->uuid( 4 ); # valid

=item * variant 5

  my $validation = $self->validation;
  $validation->input({ uuid => '987FBC97-4BED-5078-AF07-9141BA07C9F3' });
  $validation->required( 'uuid' )->uuid( 5 ); # valid

=back

=head2 hex

  my $validation = $self->validation;
  $validation->input({ hex => 'afe' });
  $validation->required( 'hex' )->hex(); # valid
  $validation->input({ hex => 'affe12' });
  $validation->required( 'hex' )->hex(); # valid

=head2 float

  my $validation = $self->validation;
  $validation->input({ float => '.31' });
  $validation->required( 'float' )->float(); # valid
  $validation->input({ float => '+3.123' });
  $validation->required( 'float' )->float(); # valid
  $validation->input({ float => '-3.123' });
  $validation->required( 'float' )->float(); # valid
  $validation->input({ float => '0.123' });
  $validation->required( 'float' )->float(); # valid
  $validation->input({ float => '0.123e1' });
  $validation->required( 'float' )->float(); # valid
  $validation->input({ float => '0.123E-13' });
  $validation->required( 'float' )->float(); # valid

=head2 ip

  my $validation = $self->validation;
  $validation->input({ ip => '1.1.1.1' });
  $validation->required( 'ip' )->ip(); # valid
  $validation->input({ ip => '255.255.255.255' });
  $validation->required( 'ip' )->ip(); # valid

IPv6

  my $validation = $self->validation;
  $validation->input({ ip => 'fe80:0:0:0:200:f8ff:fe21:67cf' });
  $validation->required( 'ip' )->ip(6); # valid
  $validation->required( 'ip' )->ip(); # invalid as IPv4 is the default


=head1 ACKNOWLEDGEMENT

Some checks are inspired by L<https://github.com/chriso/validator.js>

=head1 MORE COMMON CHECKS?

If you know some commonly used checks, please add an issue at
L<https://github.com/reneeb/Mojolicious-Plugin-AdditionalValidationChecks/issues>.

=head1 CONTRIBUTORS

Those people contributed to this addon:

=over 4

=item * Florian Heyer

=back

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
