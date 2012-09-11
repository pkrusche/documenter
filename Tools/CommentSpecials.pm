#!/usr/bin/perl

=head1 Process Special Comments within Markdown/Pod blocks

=cut
package Tools::CommentSpecials;

use strict;
our @ISA = qw(Exporter);
require Exporter;

our @EXPORT_OK = qw(markdown_specials);


=head2 Process special bits of markup

 Parameters:
 $md     : the markdown code

 Returns: 
 processed markdown.

=cut

sub markdown_specials {
	my $md = shift;

	my $state = "";
	my $out   = "";
	my @lines = split/\n/, $md;
	foreach my $l (@lines) {
		my $cpy = $l;
		$cpy =~ s/^\s+//;
		$cpy =~ s/\s+$//;

		if ($cpy=~ m/^Parameters\:$/i) {
			$state = 'bq0';
			$l = "**Parameters:** \n";
		} elsif ($cpy=~ m/^Return(s)?\:$/i) {
			$state = 'bq0';
			$l = "**Return:** \n";
		}

		if($cpy eq '') {
			$state = '';
		}

		if ($state eq 'bq') {
			$out.= ">" . $l . " \n";
		} else {
			$out.= $l . "\n";
		}

		if($state eq 'bq0') {
			$state = 'bq';
		}
	}

	return $out;
}

1;