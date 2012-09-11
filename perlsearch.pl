#!/usr/bin/perl

=head1 Perl search tool

Find things in the perl index.

=cut

use strict;
use warnings;
use feature ":5.10";

## make sure this script also works when called from somewhere else
use FindBin qw($Bin);
use lib "$Bin";

use Getopt::Long;
use Data::Dumper;
use Cwd;

use JSON;
use Tools::NamedTree;
use Tools::PerlIndex;

my $usage = 0;

my $search = '';

my $type = '';

GetOptions(
    'help|h!'             => \$usage,
    'search=s'			  => \$search,
    'type=s'			  => \$type,
);

if ($usage) {
    print <<END;
Index searcher. 

Options: 
--search : the search string for the index.
--type   : the type filter

END
    exit 0;
}

## find all packages declared here
my $idx = Tools::PerlIndex->new();

my $ids = $idx->searchIdentifiers($search, $type);

my @filtered = 
 map { 	{ 
			file => $_->{file},
			line => $_->{location},
			name => $_->{title},
			type => $_->{type},
			identifier => $_->{identifier}, 			
 		} 
 } @$ids;

print to_json (\@filtered, {pretty=>1}),  "\n";

0;
