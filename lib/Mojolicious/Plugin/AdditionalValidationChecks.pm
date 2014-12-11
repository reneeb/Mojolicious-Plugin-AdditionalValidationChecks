package Mojolicious::Plugin::AdditionalValidationChecks;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '0.05';

use Email::Valid;
use Scalar::Util qw(looks_like_number);
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
        return if !defined $_[3];
        return $_[2] < $_[3];
    });

    $validator->add_check( max => sub {
        return 1 if !looks_like_number( $_[2] );
        return if !defined $_[3];
        return $_[2] > $_[3];
    });

    $validator->add_check( phone => sub {
        return 1 if !$_[2];
        return 0 if $_[2] =~ m{\A
            (?: \+ | 00? ) [1-9]{1,3} # country
            \s*? [1-9]{2,5} \s*?      # local
            [/-]?
            \s*? [0-9]{4,12}          # phone
        \z}x;
        return 1;
    });

    $validator->add_check( length => sub {
        my ($self, $field, $value, $min, $max) = @_;

        my $length = length $value;
        return 0 if $length >= $min and !$max;
        return 0 if $length >= $min and $length <= $max;
        return 1;
    });

    $validator->add_check( http_url => sub {
        my $url = Mojo::URL->new( $_[2] );
        return 1 if !$url;
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
}

1;
__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::AdditionalValidationChecks - Mojolicious Plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('AdditionalValidationChecks');

  # Controller
  my $validation = $self->validation;
  $validation->input({ nr => 3 });
  $validation->required( 'nr' )->max( 10 );

=head1 DESCRIPTION

L<Mojolicious::Plugin::AdditionalValidationChecks> adds a few validation checks to
the L<Mojolicious validator|Mojolicious::Validator>.

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

=head1 MORE COMMON CHECKS?

If you know some commonly used checks, please add an issue at
L<https://github.com/reneeb/Mojolicious-Plugin-AdditionalValidationChecks/issues>.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
