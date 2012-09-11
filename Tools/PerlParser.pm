#!/usr/bin/perl

=head1 Perl Parser ##0
This package splits perl code into code, comments and POD code.
=cut

package Tools::PerlParser;

use strict;
use File::Temp qw(tempfile);
use Parse::RecDescent;
use Data::Dumper;

use PPI;
use PPI::Dumper;
use PPI::Find;

use Tools::PerlParser::Declaration;

use Tools::NamedTree;

# state can have three values:
#  code: code that will be pretty-printed
#  pod : pod code
#  comment : multiple lines of comments
#  end : end perl code, everything is pod
our $state = 'code';

# code buffers: current code, and everything
our $current     = "";
our $everything  = "";
our $lineno      = 0;
our $last_lineno = 1;

# PPI parser stuff
our $ppidoc = undef;

# table of contents tree
our $countents_tree = undef;

# the declarations subtree
our $declarations_node = undef;

# handler callback functions
our %handlers = ();

our $has_moose = 0;

=head2 Add a handler for a parser state.

See above for supported states.
=cut

sub setHandler {
	my ( $id, $sub ) = @_;
	our %handlers;
	$handlers{$id} = $sub;
}

=head2 Function to write out parsed source code, comment or POD comments
Variable $current contains a buffer with the parsed source. This function 
prints and formats its contents according to the current state.
=cut

sub flushcurrent {
	our %handlers;
	our ( $state, $current, $lineno, $last_lineno );
	if ( $current eq "" ) {
		return;
	}
	if ( defined( $handlers{$state} ) ) {
		$handlers{$state}->( $current, $last_lineno );
	}
	$last_lineno = $lineno + 1;
	$current     = "";
}

=head2 Main parser function
Crude line by line parser to separate lines with comments only,
code lines and pod lines.

 Parameters:
 $filename : the name of the source file to parse

=cut

sub parse {
	my $filename = shift;
	our ( $current, $lineno, $state, $everything, $last_lineno, $ppidoc,
		$has_moose );

	$state = 'code';

	# code buffers: current code, and everything
	$current     = "";
	$everything  = "";
	$lineno      = 0;
	$last_lineno = 1;
	$ppidoc      = undef;
	$has_moose   = 0;

	# initialize contents tree.
	our $contents_tree = Tools::NamedTree->new();

	$contents_tree->value(
		{
			'title'    => "Outline",
			'type'     => "nodisplay",
			'location' => 0,
		}
	);

	# headings and pod stuff goes in here.
	my $documentation_node = $contents_tree;
	# ->add_child(
	# 	{
	# 		'title'    => "Documentation",
	# 		'type'     => "h1",
	# 		'location' => 0,
	# 	}
	# );

	my @elstack = ();

	my @breaking_points = ();

	open FILE, "<" . $filename
	  or die "Input file $filename not found.";

	# first pass: get function definitions and such.

	$ppidoc = PPI::Document->new($filename);

	our $declarations_node = $contents_tree;
	# ->add_child(
	# 	{
	# 		'title'    => "Declarations",
	# 		'type'     => "h1",
	# 		'location' => 0,
	# 	}
	# );

	my $globals_node = $declarations_node;
	# ->add_child(
	# 	{
	# 		'title'    => "Global Variables",
	# 		'type'     => "h1",
	# 		'location' => 0,
	# 	}
	# );

	my $finder = PPI::Find->new( \&declarations );

	@elstack = ();
	my @found = $finder->in($ppidoc);

	my %globals = ();

	foreach my $el (@found) {
		if ( UNIVERSAL::isa( $el, "PPI::Statement::Variable" ) ) {

			# list first occurrences of global variables
			if ( $el->type() eq 'our' ) {
				foreach ( $el->variables() ) {
					if ( !defined( $globals{$_} ) ) {
						$globals{$_} = $globals_node->add_child(
							{
								title         => $_,
								type          => "global",
								location      => $el->line_number(),
								documentation => get_documentation($el),
								ppinode       => $el,
							}
						);
					}
				}
			}
			next;
		}

		# determine where to append this element
		my $append_node = $declarations_node;
		my $keepgoing   = 1;

		my $tt = get_title_and_type($el);

		my $is_package =
		     $tt->[1] eq 'package'
		  || $tt->[1] eq 'class'
		  || $tt->[1] eq 'role';

		while ( scalar @elstack > 0 && $keepgoing ) {
			my $top = $elstack[$#elstack];

			my $top_is_package =
			     $top->{'node'}->value()->{'type'} eq 'package'
			  || $top->{'node'}->value()->{'type'} eq 'class'
			  || $top->{'node'}->value()->{'type'} eq 'role';

			if ( $el->descendant_of( $top->{'element'} )
				|| ( !$is_package && $top_is_package ) )
			{
				$append_node = $top->{'node'};
				$keepgoing   = 0;
			} else {
				pop @elstack;
			}
		}

		my $el_node = $append_node->add_child(
			{
				title         => $tt->[0],
				type          => $tt->[1],
				location      => $el->line_number(),
				documentation => get_documentation($el),
				ppinode       => $el,
			}
		);

		push @elstack,
		  {
			element => $el,
			node    => $el_node,
		  };

		push @breaking_points, $el->line_number();
	}

	@elstack = ();

	# second pass: get comments, code and pod
	while (<FILE>) {
		my $line = $_;
		$everything .= $line;
		++$lineno;

		while ( scalar @breaking_points > 0
			&& $lineno >= $breaking_points[0] )
		{
			flushcurrent();
			shift @breaking_points;
		}

		$line =~ s/\s*\n$//;

		# go to pod comment state.
		if ( $line =~ m/^=(.*)/ ) {

			# create TOC entry
			if ( $line =~ m/^=head([1-9])\s+(.*)/ ) {
				my $append_node = $documentation_node;
				my $keepgoing   = 1;

				my $level = $1;
				my $text  = $2;

				while ( ( scalar @elstack > 0 ) && $keepgoing ) {
					my $top = $elstack[$#elstack];
					if ( $level <= $top->{'level'} ) {
						pop @elstack;
					} else {
						$append_node = $top->{'node'};
						$keepgoing   = 0;
					}
				}

				my @t = split /\#\#/, $text;

				my $h_node = $append_node->add_child(
					{
						title    => $t[0],
						type     => "h$level",
						location => $lineno,
						index_path => $t[1]
					}
				);

				push(
					@elstack,
					{
						level => $level,
						node  => $h_node,
					}
				);
			}

			# change state
			if ( $1 eq "cut" ) {
				if ( $state eq 'pod' ) {
					$current .= "\n=cut";
					flushcurrent();
					$state = 'code';
				} else {
					flushcurrent();
					my $tmp = $state;
					$state = 'pod';
					$current .= $line . "\n";
					flushcurrent();
					$state = $tmp;
				}
			} else {
				if ( $state ne 'pod' ) {
					flushcurrent();
				}
				$state = 'pod';
				$current .= $line . "\n";
			}

			# end of file
		} elsif ( $line =~ m/^__END__/ ) {
			flushcurrent();
			$state = 'end';

			# single line comment -- starting with at least two #'s
		} elsif ( $line =~ m/^\s*\##(.*)/ ) {
			if ( $state ne 'pod' ) {
				if ( $state ne 'comment' ) {
					flushcurrent();
				}
				$current .= $1 . "\n";
				$state = 'comment';
			} else {
				$current .= $line . "\n";
			}

			# any other lines
		} else {

		# any line that's not a comment will cause us to leave the comment state
			if ( $state eq 'comment' ) {
				flushcurrent( $state, $current );
				$state = 'code';
			}
			$current .= $line . "\n";
		}
	}
	flushcurrent();
	close FILE;
}

=head2 Get a tree of significant content elements

=cut

sub get_contents_tree {
	our $contents_tree;
	return $contents_tree;
}

=head2 PPI::Find filter for declarations

 Parameters:
 $cur : a PPI::Token

 Returns:
 1 if element fits the criteria
 0 if element does not fit
 undef if children do not need to be looked at.
 See also PPI::Find -> &wanted

=cut

sub declarations {
	my $cur = shift;
	our $has_moose;

	if ( UNIVERSAL::isa( $cur, "PPI::Statement::Include" ) ) {
		my $mod  = $cur->module();
		my $type = $cur->type();
		if ( $mod =~ m/^MooseX?/ ) {
			if ( $type eq 'no' ) {
				$has_moose = 0;
			} else {
				$has_moose = 1;
			}
		}
	}

	return Tools::PerlParser::Declaration::is_declaration( $cur, $has_moose );
}

=head2 Get all method, class, package and variable declaration nodes

 Returns:

 A Tree of declarations

=cut

sub get_declarations {
	our $declarations_node;
	return $declarations_node;
}

=head2 Get the PPI Parser document

 Returns:
 The PPI Document parsed from the input.

=cut

sub get_ppi_document {
	our $ppidoc;
	return $ppidoc;
}

=head2 Get the type and title of a PPI element

 Parameters:
 $cur : the element

 Returns:
 [ $title , $type ]

=cut

sub get_title_and_type {
	my $cur = shift;

	if ( Tools::PerlParser::Declaration::is_declaration( $cur, 1 ) ) {
		my $decl = Tools::PerlParser::Declaration->new($cur);
		return [ $decl->{title}, $decl->{type} ];
	} else {
		return [ $cur, "" ];
	}
}

=head2 Get the documentation directly preceding a PPI Element

 Parameters:
 $el : the element

 Returns:
 The first pod block in front of this statement, or all comments
 up to the first element that is not whitespace. If no pod or comments
 are found up to the first non-whitespace element, we return undef
 
=cut

sub get_documentation {
	my $el = shift;

	my $tok = $el;
	my @doc = ();
	do {
		if ( UNIVERSAL::isa( $tok, "PPI::Element" ) ) {
			$tok = $tok->previous_token();

			if ( UNIVERSAL::isa( $tok, "PPI::Token::Whitespace" ) ) {

				# skip whitespace.
			} elsif ( UNIVERSAL::isa( $tok, "PPI::Token::Comment" )
				|| UNIVERSAL::isa( $tok, "PPI::Token::Pod" ) )
			{
				unshift( @doc, $tok->content() );
				if ( UNIVERSAL::isa( $tok, "PPI::Token::Pod" ) ) {
					$tok = undef;
				}
			} else {
				$tok = undef;
			}
		} else {
			$tok = undef;
		}
	} while ( defined($tok) );
	return join( "\n", @doc );
}

sub dump {
	return Dumper(shift);
}

1;
