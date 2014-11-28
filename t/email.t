use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin 'AdditionalValidationChecks';

get '/' => sub {
  my $c = shift;

  my $validation = $c->validation;
  $validation->input( $c->req->params->to_hash );

  $validation->required( 'email' )->email();

  my $result = $validation->has_error() ? 0 : 1;
  $c->render(text => $result );
};

my %mails = (
  'dummy+cpan@perl-services.de' => 1,
  'root@localhost'              => 1,
  123                           => 1,
);

my $t = Test::Mojo->new;
for my $mail ( keys %mails ) {
    $t->get_ok('/?email=' . $mail)->status_is(200)->content_is( $mails{$mail}, "Address: $mail" );
}

done_testing();
