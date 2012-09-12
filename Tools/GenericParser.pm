#!/usr/bin/perl

use MooseX::Declare;

=head1 Generic Source Parser Class

Can parse sources 

=cut

class Tools::GenericParser {

	require Tools::NamedTree;

	## called for each bit of code discovered
	## takes two parameters: $code, and $line
	has 'code_handler' => (
		is => 'rw',
		isa => 'CodeRef|Undef',
	);

	## called for each bit of short/single-line comment discovered
	## (note though that the parser concatenates subsequent comment)
	## lines
	## takes two parameters: $comment, and $line
	has 'comment_handler' => (
		is => 'rw',
		isa => 'CodeRef|Undef',
	);

	## called for each bit of markup comment discovered
	## takes two parameters: $comment, and $line
	has 'markup_handler' => (
		is => 'rw',
		isa => 'CodeRef|Undef',
	);

	## Parsing Parameters

	## Characters to start a single-line 
	## comment with (there can be multiple options)
	has 'single_line_start' => (
		is => 'rw',
		isa => 'ArrayRef[Str]',
		default => sub { return ['//'] },
	);

	## Multiline comments. Must come in 
	## pairs, first is start, second is end
	has 'multi_line' => (
		is => 'rw',
		isa => 'ArrayRef[Str]',
		default => sub { return ['/*', '*/'] }
	);

	## here we store the contents tree that is built
	has 'tree' => (
		is => 'rw',
		isa => 'Tools::NamedTree',
		default => sub { 
		 	my $t = Tools::NamedTree->new;
		 	$t->value({
				'title'    => "Outline",
				'type'     => "nodisplay",
				'location' => 0,
			});
			return $t;
		},
	);

=head2 Parse a file

 Parameters:
 $filename : the name of the file

 Returns:
 nothing. Updates the contents tree

=cut

	method parse(Str $filename) {
		my $data = "";
		{ local $/ = undef; local *FILE; open FILE, "<", 
			$filename or die "Cannot open $filename"; 
			$data = <FILE>; close FILE };
		my @lines = split /[\n]/, $data;

		my $state = {
			_s => 'code',
			_l => 0,
			_t => "",
		};

		for (my $line = 0; $line < (scalar @lines); $line++) {
			my $linedata = $lines{$line};
			my $line_nows = $linedata;
			$line_nows =~ s/^\s+//;
			$line_nows =~ s/[\s\n\r]+$//;

			if ($state eq 'code') {
				my $line_nocomment = $linedata;
				foreach my $slc (@{$self->single_line_start}) {
					if ( index($linedata, $slc) == 0 ) {
						$state = 'comment'
					}
				}
			} else {
				# else...
			}
		}
	}

=head2 Helper to change current state

Updates the state at the end of a block

 Parameters:
 $self  : the self object
 $state : the state hash
 $line  : the current line number
 $new_state : the new state

=cut
	sub _change_state {
		my $self  = shift;
		my $state = shift;
		my $line  = shift;
		my $new_state = shift;

		if ($state->{_s} eq 'code') {
			if (defined $self->code_handler) {
				$self->code_handler->($state->{_t}, $state->{_l});
			}
		} elsif ($state->{_s} eq 'comment') {
			if (defined $self->comment_handler) {
				$self->comment_handler->($state->{_t}, $state->{_l});
			}
		} elsif ($state->{_s} eq 'markup') {
			if (defined $self->markup_handler) {
				$self->markup_handler->($state->{_t}, $state->{_l});
			}
		} else {
			print STDERR 'output in state ', $state->{_s}, ' was ignored', "\n";
		}

		$state->{_s} = $new_state;
		$state->{_l} = $line;
		$state->{_t} = "";
	}
};
