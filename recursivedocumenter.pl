#!/usr/bin/perl -w

=head1 Recursive documentation generator

=cut

use strict;
use warnings;
use feature ":5.10";

## make sure this script also works when called from somewhere else
use FindBin qw($Bin);
use lib "$Bin";

use File::Copy;
use File::Find;
use File::Spec qw(catfile catdir);
use Getopt::Long;
use Cwd;
use Cwd qw(abs_path);
use Data::Dumper;
use List::Util qw(sum);
use JSON;
use Scalar::Util qw(looks_like_number);
use Pod::Usage;

## Get the perl executable
my $perl_command = $^X;
$perl_command = qq{"$perl_command"}
  if $perl_command =~ /\s/;

## output parameters
# output directory to write to
our $outputdirectory = "./docs";

# directory with images and additional source files.
our $sourcedirectory = "$Bin";

# the base url for the index RSS file
my $baseurl = "http://localhost:4000/";

# true when only printing usage message
my $usage = 0;

# the output format. Passed to documenter.pl
our $format = 'html';

# force updates even if files haven't changed
our $force = 0;

our @rootdir = ();

GetOptions(
	'outputdirectory|o=s' => \$outputdirectory,
	'sourcedirectory|s=s' => \$sourcedirectory,
	'format=s'            => \$format,
	'help|h!'             => \$usage,
	'ignoredir=s'         => \@rootdir,
	'force|f!'			  => \$force,
	'baseurl=s'           => \$baseurl
);
@rootdir = split( /,/, join( ',', @rootdir ) );

unless ($format eq 'html' || $format eq 'md') {
	die "Format must be html or md."
}

if ($usage) {
	print pod2usage( -sections => "NAME|SYNOPSIS|OPTIONS|DESCRIPTION" );
	exit 0;
}

my @directories = ();

if ( scalar @ARGV <= 0 ) {
	push @directories, "./";
}

foreach (@ARGV) {
	push @directories, $_;
}

if (!-e $outputdirectory || !-d $outputdirectory || !-w $outputdirectory) {
	die "Cannot write directory $outputdirectory";
} else {
	print "Writing to $outputdirectory\n";
}

## ignore output directory
push @rootdir, $outputdirectory;
push @rootdir, File::Spec->catdir($directories[0], '.git');

my $ignores_file = File::Spec->catfile($directories[0], '.docignore');
if( -e $ignores_file ) {
	my $dign;
	{ local $/ = undef; local *FILE; open FILE, "<", $ignores_file;
		$dign = <FILE>; close FILE }
	my @digns = split /[\r\n]+/, $dign;
	push @rootdir, File::Spec->catdir($directories[0], $_) foreach @digns;
}

for (my $i = 0; $i < scalar @rootdir; $i++) {
	eval {
		$rootdir[$i] = abs_path($rootdir[$i]);
	};
	if ($@) {
		print "[W] $rootdir[$i] cannot be ignored because it doesn't exist.\n$@\n";
	}
}

## remove the index file (it's regenerated every time)
unlink (File::Spec->catfile($outputdirectory, 'index.html'));

our $stuff_was_copied = 0;

## find all files we can document
find( { 'wanted' => \&wanted, no_chdir => 1, }, @directories );

=head2 Find filter that runs documenter if the file matches things we can use for
documentation

=cut

sub wanted {
	our @rootdir;
	our $outputdirectory;
	our $sourcedirectory;
	our $force;
	my $documenterpl = File::Spec->catfile($Bin, "documenter.pl");

	my $nametopass = $_;
	my $abs_name = abs_path($nametopass);
	my $sd_abs_path_ignore = File::Spec->catdir(
		abs_path($sourcedirectory), "_");

	if ($^O eq 'MSWin32') {
		$sd_abs_path_ignore =~ s/\\/\//g;
	}

	return if index($abs_name, $sd_abs_path_ignore) == 0;

	foreach my $rd (@rootdir) {
		# print "Testing $abs_name against $rd...";
		if(index($abs_name, $rd) == 0) {
			# print " rejected\n";
			return;
		}
		# print " ok.\n";
	}

	# Perl files and Perl Modules
	if ( $nametopass =~ m/\.p[lm]$/i 
	  || $nametopass =~ m/\.markdown$/i 
	  || $nametopass =~ m/\.md$/i 
	  || $nametopass =~ m/\.html?$/i 
	  || $nametopass =~ m/\.js$/i 
	  || $nametopass =~ m/\.css$/i 
	  || $nametopass =~ m/\.pod$/i 
	  || $nametopass =~ m/README$/i 
	  || $nametopass =~ m/LICENSE$/i 
	  ) {

		## Check if the source file is newer than the HTML file
        my $htmlfilename = $nametopass . ".html"; 
		$htmlfilename =~ s/^\.\///;
        $htmlfilename =~ s/\//_/g;
        $htmlfilename = File::Spec->catfile($outputdirectory, $htmlfilename);
        if (-e $htmlfilename && !$force) {
			my @m1 = stat($nametopass);
			my @m2 = stat($htmlfilename);
			
			if ( $m2[9] > $m1[9] ) {
				print "$nametopass hasn't changed, skipping...\n";
				return;
			} else {
				print "Updating $_ -> $htmlfilename\n";
			}
        } else {
				print "Documenting $_ -> $htmlfilename\n";
        }

        if ($stuff_was_copied) {
			system 	$perl_command, 
					$documenterpl,
					"--format", $format, 
					"-n", 
					"-v", # verbose
					"--outputdirectory", $outputdirectory,
					"--sourcedirectory", $sourcedirectory,
					$nametopass;
        } else {
			system 	$perl_command, 
					$documenterpl,
					"-v", # verbose
					"--format", $format, 
					"--outputdirectory", $outputdirectory,
					"--sourcedirectory", $sourcedirectory,
					$nametopass;
			$stuff_was_copied = 1;        	
        }
	}
}

## make static index
print "Making static index.\n";
system 	$perl_command, 
		File::Spec->catfile($Bin, 'staticindex.pl'),
		File::Spec->catfile($outputdirectory, 'index.json'), 
		$baseurl,
		$format;

## check if we have to create an index file
my $indexfile = File::Spec->catfile($outputdirectory, "index.$format");
if(!-e $indexfile) {
	my @files_to_try = (
		File::Spec->catfile($outputdirectory, "README.md.$format"),
		File::Spec->catfile($outputdirectory, "README.markdown.$format"),
		File::Spec->catfile($outputdirectory, "static_index.html"),
	);

	foreach my $f (@files_to_try) {
		if(-e $f) {
			print "Using $f as the index page.\n";
			copy ($f, $indexfile)
				or die "Cannot copy the index file.";
			last;
		}
	}
}

__END__

=pod

=head1 NAME

Recursive Documenter : Run Documenter on folders and subfolders

=head1 SYNOPSIS

recursivedocumenter.pl [options] <dir1> <dir2> ...

=head1 OPTIONS

--outputdirectory <dirname> : set an output directory for the
                              generated HTML files.
							  
							  Default value: "./doc"

--sourcedirectory <dirname> : set an source directory to copy
                              styles, images, etc. from
							  
                              This directory will default to the
							     location of documenter.

--ignoredir <dirname>       : add directories to ignore

--force 					: force updating files even if source 
							  hasn't changed.

--format                    : output format (md or html, default is html)

--baseurl                   : base url for index generation, default is
                              http://localhost:4000

=head1 DESCRIPTION

This tool will run the documenter script on all source files in a
given folder and all subfolders.

=cut

