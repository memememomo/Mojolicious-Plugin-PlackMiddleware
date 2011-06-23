package TestFilter;
use strict;
use warnings;
use base qw( Plack::Middleware );

sub call {
	
	my $self = shift;
	my $res = $self->app->(@_);
	$self->response_cb($res, sub {
		return sub {
			if (my $chunk = shift) {
				return $chunk. '[filtered]';
			}
		};
		$res;
	});
}

1;

__END__