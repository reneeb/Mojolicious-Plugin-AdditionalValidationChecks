package Mojolicious::Plugin::AdditionalValidationChecks;
use Mojo::Base 'Mojolicious::Plugin';

our $VERSION = '0.01';

use Email::Valid;

sub register {
    my ($self, $app) = @_;

    my $email = Email::Valid->new(
        allow_ip => 1,
    );

    my $validator = $app->validator;
    $validator->add_check( email => sub {
        my ($self, $field, $value, @params) = @_;
        my $address = $email->address( @params, -address => $value );
        return $address ? 1 : undef;
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

=head2 min

=head2 max

=head2 length

=head2 int

=head2 url

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
