
use MooseX::Declare;

=head1 Tree with named nodes

Extends the standard tree class to have named nodes

=cut
class Tools::NamedTree extends Tools::Tree {

	use Carp qw(croak);
	use Data::Dumper;
	
	# name of this node
	has 'name' => (
		is => 'rw',
		isa => 'Str',
		default => "",
	);
	
=head2 Check if a named path exists in this tree

 Parameters:
 $path : an array of path elements. the first element is compared
         to $self->{name}, the following ones to the children
 
 Returns: 
 The NamedTree corresponding to the path, or undef if no such tree was found

=cut	

	method has_path (ArrayRef $path) {
		if (scalar @$path == 1 ) {
			if ($self->{name} eq $path->[0]) {
				return $self;
			}
		} elsif (scalar @$path > 1 && 
				 $self->{name} eq $path->[0]
		) {
			my @vals = @$path;
			shift @vals;
			foreach my $c (@{$self->{children}}) {
				my $result = $c->has_path(\@vals);
				if(defined ($result)) {
					return $result;
				}
			}
		}
		return undef;
	}

=head2 Make a child node with a given path (unless it already exists)

 Parameters: 
 $path : an array of path elements. the first element is compared
         to $self->{name}, the following ones to the children
 $value : a value to append to the new child
 
 Returns: 
 The NamedTree corresponding to the path
 
=cut
	method make_path (ArrayRef $path, Any $value) {
		if(scalar @$path == 0) {
			croak ("NamedTree::make_path : empty path given.");
		}
		if (scalar @$path == 1 ) {
			if ($self->name() eq $path->[0]) {
				$self->value($value);
				return $self;
			} 
		} elsif (scalar @$path > 1 && 
				 $self->name() eq $path->[0]
		) {
			my @vals = @$path;
			shift @vals;
			foreach my $c (@{$self->{children}}) {
				if($c->name() eq $vals[0]) {
					my $result = $c->make_path(\@vals, $value);
					return $result;
				}
			}
			# if we end up here, we haven't found any child with an appropriate 
			# name
			my $child = $self->add_child(undef);
			$child->name($vals[0]);
			
			return $child->make_path(\@vals, $value); 
		}
		croak ("NamedTree::make_path : will not rename $self->{name} ".
			  "to $path->[0]");
	}

=head2 Convert tree to JSON-compatible tree.

 Returns:
 untyped, JSON-compatible tree (removing the parent links)
=cut
    method TO_JSON () {
        my $h = $self->SUPER::TO_JSON;
        $h->{name} = $self->name;
        return $h;
    }

=head2 restore parent links and blessings after serializing to JSON

 Parameters:
 $hash : JSON-compatible hash (see TO_JSON)

 Returns:
 $self
=cut
    method FROM_JSON(HashRef $hash) {
    	$self->SUPER::FROM_JSON($hash);
    	$self->name($hash->{name});
        return $self;
    }
};