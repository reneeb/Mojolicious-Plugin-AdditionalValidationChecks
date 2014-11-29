package Mojolicious::Plugin::AdditionalValidationChecks;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '0.01';

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
    });

    $validator->add_check( length => sub {
    });

    $validator->add_check( http_url => sub {
        my $url = Mojo::URL->new( $_[2] );
        return 1 if !$url;
        return 1 if !$url->is_abs;
        return 1 if !grep{ $url->scheme eq $_ }qw(http https);
        return 0;
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

*not implemented yet*

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

*not implemented yet*

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

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
