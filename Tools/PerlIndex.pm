=head1 Perl Library Indexer

Create an index of perl files that allows retrieval of declarations
and references to these.

=cut
package Tools::PerlIndex;

use strict;
use warnings;
use feature ":5.10";

use Carp qw(croak);
use Cwd;
use File::Find;
use File::Spec;
use Data::Dumper;
use Storable qw(retrieve nstore);
use Digest::MD5 qw(md5_hex);
use Module::CoreList;

use PPI;

use Tools::PerlParser;

=head1 Constructor
 
 Parse a directory of perl modules into an index.

=cut
sub new {
	my $class = shift;
	my $directory = shift || getcwd;
	
	my $self = bless ({
		files => [],
		identifiers => {},
		declarations => [],
		ppidocuments => {},
		sourcedirectory => $directory,
		md5s => {},
	}, $class);
	
	my @directories = ($directory);
	
	my $ddbfile = File::Spec->catfile(@directories, ".refactoring_declarations");
	my $mdbfile = File::Spec->catfile(@directories, ".refactoring_checksums");
	my $pdbfile = File::Spec->catfile(@directories, ".refactoring_parsing");
	
	if(-e $ddbfile) {
		$self->{declarations} = retrieve($ddbfile);

		if(-e $mdbfile) {
			$self->{md5s} = retrieve($mdbfile);		
		}
		if(-e $pdbfile) {
			$self->{ppidocuments} = retrieve($pdbfile);		
		}
	}
	
	my @files = ();
	
	find( { 'wanted' => sub { push @files, $_ if m/\.p[lm]$/ }, 
			no_chdir => 1, }, @directories );

	$self->{files} = \@files;
	
	foreach my $parsedfile (keys %{$self->{ppidocuments}}) {
		unless (grep /^$parsedfile$/, @files) {
			print STDERR "Removing $parsedfile from cache\n";
	
			my @decl_cpy = ();
			foreach my $decl (@{$self->{declarations}}) {
				if($decl->{file} ne $parsedfile) {
					push @decl_cpy, $decl;
				}
			}
			$self->{declarations} = \@decl_cpy;
			delete $self->{ppidocuments}->{$parsedfile};
			delete $self->{md5s}->{$parsedfile};
		}		
	}
	
	foreach my $file (@files) {

		my $filemd5 = "";
		{
			local $/ = undef; 
			open(FILE, $file) or die "Can't open '$file': $!";
	    	binmode(FILE);
			$filemd5 = md5_hex(<FILE>);
			close(FILE);			
		}

		if ( exists ($self->{md5s}->{$file}) 
		  && $self->{md5s}->{$file} eq $filemd5 ) {
			# file has not changed and we have it's parse tree, too
			# leave it be.
			
			if(defined ($self->{ppidocuments}->{$file})) {
				goto NEXT;
			}
		} 

		# remove all declarations in this file from our index
		print STDERR "Recreating cache for $file\n";

		my @decl_cpy = ();
		foreach my $decl (@{$self->{declarations}}) {
			if($decl->{file} ne $file) {
				push @decl_cpy, $decl;
			}
		}
		$self->{declarations} = \@decl_cpy;
		
		Tools::PerlParser::parse($file);
		$self->{ppidocuments}->{$file} = Tools::PerlParser::get_ppi_document();
		
		my %linenumbers;
		
		Tools::PerlParser::get_declarations()->traverse(sub {
			my $identifier = "$file\:\:$_->[0]->{title}";
			my $type = $_->[0]->{type};

			if($type eq 'package' || $type eq 'class') {
				$identifier = $_->[0]->{title};
			}
			
			$identifier =~ s/^$directory\/?//;
			$identifier =~ s/\//::/g;
			$identifier =~ s/\.p[lm]\:\:/::/g;
			
			my $r = {
				file => $file,
				location => $_->[0]->{location},
				name => $_->[0]->{title},
				type => $type,
				identifier => $identifier,
				ppinode => $_->[0]->{ppinode},
				ppidoc => $self->{ppidocuments}->{$file},
			};
			
			push @{$self->{declarations}}, $r;
		});
	NEXT:
		$self->{md5s}->{$file} = $filemd5;
	}
	
	foreach my $r (@{$self->{declarations}}) {
		# print "$r->{identifier} : $r->{type}\n";
		$self->{identifiers}->{$r->{identifier}} = $r;
	}
	
	nstore($self->{declarations}, $ddbfile);
	nstore($self->{ppidocuments}, $pdbfile);
	nstore($self->{md5s}, $mdbfile);
	
	return $self;
}

=head1 Split a perl identifier name into a path, a file name and a declaration 
name

 Parameters: 
 $source : the identifier
 $mustexist : 1 if the identifier must exist
 
 Returns: 
 a declaration record:
 {
 	file => <filename>,
 	location => line number,
 	
 }

=cut
sub splitPath {
	my $self = shift;
	my $source = shift || die "Empty identifier";
	my $mustexist = shift || 0;

	my $file;
	my $decl;

	if($mustexist) {
		if(exists ($self->{identifiers}->{$source})
		&& defined ($self->{identifiers}->{$source})) {
			return $self->{identifiers}->{$source};
		} else {
			croak "'$source' is not defined";
		}
	} else {
		my @parts = split /\:\:/, $source;
		my $r = {};

		$r->{identifier} = $source;
		$r->{type} = "unknown";
		$r->{location} = "unknown";
		
		if(scalar @parts >= 2) {
			$r->{name} = pop @parts;
			$r->{file} = pop @parts;
			$r->{file} =
				File::Spec->catfile(@parts, $r->{file} . ".pm");
		} else {	# scalar @parts must be == 1, since otherwise $source
					# would have been empty
			$r->{name} = join "::", @parts;
			$r->{file} = 
				File::Spec->catfile(@parts, $r->{name} . ".pm");
		}
		
		$r->{file} = File::Spec->catfile(
			( $self->{sourcedirectory} ),
			$r->{file} );
		
		$r->{file} =~ s/[\$\@\%]//g;
		
		return $r;
	}
	
	return undef;
} 

=head1 Get all references to an identifier 

 Parameters:
 $self : a PerlIndex
 $id : identifier
 
 Returns
 
 ARRAYREF to all references including file, line number, and match string
 
 [ { file => ..., location => ..., match => ..., ppidoc => PPI document, 
 	ppitok => PPI start token,
   }, ... ]

=cut
sub getReferences {
	my $self = shift;
	my $id = shift;

	# package identifiers include their name twice
	my $pid = $id;
	$pid =~ s/([^\:]+)\:{2}\g1$/$1/;
	
	my $r = $self->splitPath($id, 1);
	
	my @references = ();
	
	my $containingpackage = $r->{identifier};
	my $title = $r->{name};
	
	# when packages are declared inside packages inside files,
	# we want to also find references where just the top level
	# file package is included.
	$containingpackage =~ s/\:\:$title$//;
	
	foreach my $file ( @{$self->{files}} ) {
		given ($r->{type}) {
			when ( [ qw/package class role/ ] ) {
				my $Document = $self->{ppidocuments}->{$file};

				 # Create the Find object
  				my $Find = PPI::Find->new( sub {
  					if(UNIVERSAL::isa($_[0], "PPI::Statement::Include" ) ) {
  						my $mod = $_[0]->module;
  						if ($_[0]->type ne "no"
  						&&  ( $mod eq $pid
  						    ||  $mod eq $containingpackage ) 
  						) {
  							return 1;
  						}
  					} 
  					return 0;
  				} );
  
				# Return all matching Elements as a list
				my @found = $Find->in( $Document );
				
				foreach my $f (@found) {
					push @references, {
						file => $file,
						location => $f->line_number,
						match => $f->content,
						ppidoc => $Document,
						ppitok => $f,
					}
				}
								
			}
			default {
				die "Searching for references of type $r->{type} ".
					"is not supported";
			}
		}
	}
	
	return \@references;
}


=head2 Search find all module dependencies

 Parameters:
 $self              : the self object
 $external_only=0   : 1 to only list packages not found in the index
 $core_minversion=5 : minimum core version to contain the package

 Returns:
 {
 	package => [ 
 		references
 	]
 }
=cut

sub getDependencies {
	my $self = shift;
	my $external_only = shift || 0;
	my $core_minversion = shift || 5;
	my %pkgs = ();

	foreach my $file ( @{$self->{files}} ) {
		my $Document = $self->{ppidocuments}->{$file};

		 # Create the Find object
		my $Find = PPI::Find->new( sub {
			if(UNIVERSAL::isa($_[0], "PPI::Statement::Include" ) ) {
				my $mod = $_[0]->module;
				if ( 
					# ignore 'no' includes
					$_[0]->type ne "no"
				) {
					return 1;
				}
			} 
			return 0;
		} );

		# Return all matching Elements as a list
		my @found = $Find->in( $Document );
		
		foreach my $f (@found) {
			my $mod = $f->module;

			my $frel = Module::CoreList->first_release($mod) || 0;

			# filter internal modules
			next if $external_only && defined($self->{identifiers}->{$mod});

			# filter core modules
			# print "$mod : $frel\n";
			next if $frel >= $core_minversion;

			unless ($pkgs{$mod}) {
				$pkgs{$mod} = [];
			}

			push @{$pkgs{$mod}}, {
				file => $file,
				line => $f->line_number,
				match => $f->content,
			};
		}
	}
	return \%pkgs;
}

=head1 Search for identifiers using regular expressions

 Parameters:
 $self : a PerlIndex
 $expr : a regular expression
 $type : undef, or restriction to a type
 
 Returns:
 An ARRAYREF to a list of declarations 

=cut
sub searchIdentifiers {
	my $self = shift;
	my $expr = shift;
	my $type = shift || "";

	my @return = ();
	
	while (defined ($type)) {
		foreach my $r (@{$self->{declarations}}) {
			if( index ($r->{identifier}, $expr) >= 0
			&& ($type eq "" || $r->{type} eq $type)
			) {
				push @return, $r;
			}
		}
		$type = shift;
	}
	
	return \@return; 
}

1;