=head1 Declaration class

Base class for 

=cut
package Tools::PerlParser::Declaration;

use strict;
use warnings;

use Scalar::Util qw (blessed);

# everything that will be accepted as a Moose keyword
our @moose_keywords =
  ( "method", "class", "role", "type", "subtype", "enum", "has" );


=head2 Constructor for a new declaration element

Parameters:
$ppinode : a PPI Element from the PPI parse tree

Returns:
A blessed Declaration HASHREF

=cut
sub new {
    my $class = shift;
    my $cur = shift;
    my $self = bless {}, $class;
    
    $self->{ppinode} = $cur;
    
    if ( UNIVERSAL::isa( $cur, "PPI::Statement::Package" ) ) {
        $self->{title} = $cur->schild(1)->content();
        $self->{type} = "package";
    }
    elsif ( UNIVERSAL::isa( $cur, "PPI::Statement::Sub" ) ) {
        $self->{title} = $cur->name();
        $self->{type} = "sub" ;
    }
    elsif ( UNIVERSAL::isa( $cur, "PPI::Statement::Variable" ) ) {
        $self->{title} = ( join ";", $cur->variables() );
        $self->{type} = $cur->type();
    }
    elsif ( UNIVERSAL::isa( $cur, "PPI::Token::Word" ) ) {
        our @moose_keywords;
        my $stype = $cur;
        my $sname = undef;

        my $match = 0;

        foreach (@moose_keywords) {
            if ( $_ eq $cur->content() ) {
                $match = 1;
                last;
            }
        }
        $sname = $cur->next_token();
        while (defined($sname)
            && $sname
            && !$sname->significant() )
        {
            $sname = $sname->next_token();
        }

        if ( defined($sname) && $sname ) {
            $self->{title} = $sname->content();
            $self->{type} = $stype->content();
        }

    }
    elsif ( UNIVERSAL::isa( $cur, "PPI::Element" ) ) {
        $self->{title} = $cur->content();
        $self->{type} = blessed($cur);
    }
    else {
        $self->{title} = $cur;
        $self->{type} = "unknown";
    }
    
    return $self;
}


=head2 Static: Check if a PPI node is a declaration

Parameters:
$cur : a PPI element
$has_moose : 1 if Moose declarations should be accepted

Returns:
1 if $cur points to a declaration, 0 otherwise

=cut
sub is_declaration {
    my $cur = shift;
    my $has_moose = shift;
    
    if ( UNIVERSAL::isa( $cur, "PPI::Statement::Package" ) ) {
        return 1;
    }
    elsif ( UNIVERSAL::isa( $cur, "PPI::Statement::Sub" ) ) {
        return 1;
    }
    elsif ( UNIVERSAL::isa( $cur, "PPI::Statement::Variable" ) ) {
        return 1;
    }
    elsif ($has_moose) {
        our @moose_keywords;

        my $stype = $cur;
        my $sname = undef;

        if ( UNIVERSAL::isa( $cur, "PPI::Token::Word" ) ) {
            my $match = 0;

            foreach (@moose_keywords) {
                if ( $_ eq $cur->content() ) {
                    $match = 1;
                    last;
                }
            }

            return 0 unless $match;

            $sname = $cur->next_token();
            while (defined($sname)
                && $sname
                && !$sname->significant() )
            {
                $sname = $sname->next_token();
            }

            if ( defined($sname) && $sname ) {
                return 1;
            }
        }

    }
    return 0;
}

=head2 Change the name of a declaration 

=cut
sub rename {
    my $cur = shift;
    my $newname = shift;
    my $has_moose = shift;
    
    if ( UNIVERSAL::isa( $cur, "PPI::Statement::Package" ) 
    ||   UNIVERSAL::isa( $cur, "PPI::Statement::Sub" )
    ) {
        $cur->schild(1)->{content} = $newname;
    }
    elsif ( UNIVERSAL::isa( $cur, "PPI::Statement::Variable" ) ) {
        die "Cannot rename variables so far."
    }
    elsif ($has_moose) {
        our @moose_keywords;

        my $stype = $cur;
        my $sname = undef;

        if ( UNIVERSAL::isa( $cur, "PPI::Token::Word" ) ) {
            my $match = 0;

            foreach (@moose_keywords) {
                if ( $_ eq $cur->content() ) {
                    $match = 1;
                    last;
                }
            }

            return 0 unless $match;

            $sname = $cur->next_token();
            while (defined($sname)
                && $sname
                && !$sname->significant() )
            {
                $sname = $sname->next_token();
            }

            if ( defined($sname) && $sname ) {
                $sname->{content} = $newname;
            }
        }

    }
}

=head2 Get the starting location of the declaration

Returns:
[ Start token, End token ]

=cut
sub get_start_and_end_tokens {
    my $self = shift;
    
    my $start = $self->{ppinode};
    my $end = $start->next_sibling()->previous_token();
    
    return [$start, $end];
}

1;
