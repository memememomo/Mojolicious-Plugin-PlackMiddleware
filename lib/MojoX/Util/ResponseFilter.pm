package MojoX::Util::ResponseFilter;
use strict;
use warnings;
use Mojo::Server::PSGI;
use Mojo::Message::Response;
use Plack::Builder;
use base qw(Exporter);
our @EXPORT_OK = qw(enable);
our $VERSION = '0.05';

use Data::Dumper;
no warnings 'redefine';

    sub enable {
        
        my ($app, $mws) = @_;
        
        $app->hook(after_dispatch => sub {
            my $controller = shift;
            my @mws = @$mws;
            my $res = _generate_psgi_res($controller->res);
            my $plack_app = sub {$res};
            while (my $e = shift @mws) {
                require File::Spec->catdir(split(/::/, $e)). '.pm';
                if (ref $mws[0] eq 'ARRAY') {
                    $plack_app = $e->wrap($plack_app, @{shift @mws});
                } else {
                    $plack_app = $e->wrap($plack_app);
                }
            }
            $controller->tx->res(_generate_mojo_res($plack_app->()));
        });
    }
    
    sub _generate_mojo_res {
        my $res = shift;
        my $mojo_res = Mojo::Message::Response->new;
        $mojo_res->code($res->[0]);
        my $headers = $mojo_res->headers;
        while (scalar @{$res->[1]}) {
            my $key = shift @{$res->[1]};
            my $value = shift @{$res->[1]};
            $headers->header($key => $value);
        }
        
        # Content-Length should be set by mojolicious
        $headers->header('Content-Length' => 0);
        
        if (ref $res->[2] eq 'ARRAY') {
            my $body = '';
            while (my $chunk = shift @{$res->[2]}) {
                $body .= $chunk;
            }
            $mojo_res->body($body);
        } else {
            $mojo_res->body($res->[2]->{getline}->());
        }
        return $mojo_res;
    }
    
    sub _generate_psgi_res {
        
        my $res = shift;
        
        my $status = $res->code;
        my $headers = $res->content->headers;
        my @headers;
        for my $name (@{$headers->names}) {
            for my $values ($headers->header($name)) {
                push @headers, $name => $_ for @$values;
            }
        }
        
        my $body = Mojo::Server::PSGI::_Handle->new(_res => $res);
        return [$status, \@headers, $body];
    }

1;

__END__

=head1 NAME

MojoX::Util::ResponseFilter - ResponseFilter in Plack::Middleware style [EXPERIMENTAL]

=head1 SYNOPSIS

    sub startup {
        ....

        use MojoX::Util::ResponseFilter 'enable';
        enable($self, [
            'Plack::Middleware::Some',
            'Plack::Middleware::Some2' => \@args,
        ]);
    }
    
    package Plack::Middleware::Some;
    use strict;
    use warnings;
    use base qw( Plack::Middleware );
    
    sub call {
        
        my $self = shift;
        my $res = $self->app->(@_);
        $self->response_cb($res, sub {
            my $res = shift;
            my $h = Plack::Util::headers($res->[1]);
            if ($h->get('Content-Type') =~ 'text/html') {
                return sub {
                    my $chunk = shift;
                    
                    ### DO SOMETHING
                    
                    return $chunk;
                };
            }
            $res;
        });
    }

=head1 DESCRIPTION

MojoX::Util::ResponseFilter allows you to activate Plack::Middleware style body
filters on after_dispatch hook.

=head1 METHODS

=head2 MojoX::Util::ResponseFilter::enable($mojo_app, $args_array_ref)

Sets Plack::Middleware::* to after_dispatch hook of mojo app as a callback.

    MojoX::Util::ResponseFilter->enable($mojo_app, ['some::mw1','some::mw2'])

Middleware arguments can be set in array refs following to package name.

    MojoX::Util::ResponseFilter->enable($mojo_app, [
        'some::mw1' => [$args1, $args2],
        'some::mw2' => [$args1, $args2],
    ])

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut