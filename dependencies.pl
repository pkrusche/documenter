#!/usr/bin/perl

=head1 Generate package dependencies

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

# show help
my $usage = 0;

# ignore core packages present in this or higher
my $coreversion = 5;

# show only external dependencies
my $externals_only = 1;

GetOptions(
    'help|h!'             => \$usage,
    'coreversion=i'       => \$coreversion,
    'ext|e!'              => \$externals_only,
);

if ($usage) {
    print <<END;
Package dependency finder. Will list all package dependencies for modules
found in subfolders of the current directory.

Options: 

 --coreversion x : hide perl internals present in version >=x (default: x=5)
 
 --ext/-e        : show only external references (to packages not found in the index)

END
    exit 0;
}

## find all packages declared here
my $idx = Tools::PerlIndex->new();

my $deps = $idx->getDependencies($externals_only, $coreversion);

print to_json ($deps, {pretty => 1});