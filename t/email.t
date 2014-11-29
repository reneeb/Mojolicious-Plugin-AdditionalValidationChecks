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

get '/local' => sub {
  my $c = shift;

  my $validation = $c->validation;
  $validation->input( $c->req->params->to_hash );

  $validation->required( 'email' )->email(-fqdn => 0);

  my $result = $validation->has_error() ? 0 : 1;
  $c->render(text => $result );
};

my %mails = (
  'dummy+cpan@perl-services.de' => 1,
  'root@localhost'              => 0,
  123                           => 0,
);

my $t = Test::Mojo->new;
for my $mail ( keys %mails ) {
    (my $esc = $mail) =~ s/\+/\%2B/g;
    $t->get_ok('/?email=' . $esc)->status_is(200)->content_is( $mails{$mail}, "Address: $mail" );
}

$t->get_ok('/local?email=root@localhost')->status_is(200)->content_is( 1, "Local Address: root\@localhost" );

done_testing();
