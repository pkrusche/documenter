#!/usr/bin/perl -w

=head1 Literate Programming Automatic Documenter

This is a tool to make source code more accessible and
automatically generate documentation for source code that
contains few comments.

It will recognize POD comments and some special markup.

The result is a pretty HTML version of your source file(s),
together with an outline.

=cut

use strict;
use warnings;
use feature "state";

## make sure this script also works when called from somewhere else
use FindBin qw($Bin);
use lib "$Bin";

## import HTML::Entities to escape stuff to HTML
use File::Spec qw(catfile catdir);
use File::Basename;
use File::Copy;
use HTML::Entities;
use Data::Dumper;
use Getopt::Long;
use Cwd;
use JSON;
use Template;
use Storable;

## These are our own tool libraries
use Tools::NamedTree;
use Tools::PerlParser;
use Tools::Output;
use Tools::Output::HTML;

=head2 Option parsing

=cut

## the input parameters

# input source file name
my $filename = 'documenter.pl'; 

# output directory to write to
my $outputdirectory = "./docs";

# directory with images and additional source files.
my $sourcedirectory = $Bin;

## output parameters:
# true when only printing usage message
my $usage = 0;

# true to prevent copying js/images/etc.
my $nohelpercopy = 0;

# output format
my $format = 'html';

# make an index file
my $mkindex = 1;

my $verbose = 0;

GetOptions(
    'outputdirectory|o=s' => \$outputdirectory,
    'sourcedirectory|s=s' => \$sourcedirectory,
    'help|h!'             => \$usage,
    'nohelpercopy|n!'     => \$nohelpercopy,
    'index|i!'            => \$mkindex,
    'format|f=s'          => \$format,
    'verbose|v!'          => \$verbose,
);

if ($usage) {
    print <<'END';
Code Documenter usage:

documenter.pl [options] <filename>

Where [options] can be

--outputdirectory <dirname> : set an output directory for the
                              generated HTML files.
							  
							  Default value: "./"

--sourcedirectory <dirname> : set an source directory to copy
                              styles, images, etc. from
							  
                              This directory will default to the
							  location of documenter.pl.

--format <html/md>          : specify the output format

--index                     : make an index file, too.

END
    exit 0;
}

$filename = $ARGV[$#ARGV]
  if scalar @ARGV > 0;

if ( !-f $filename ) {
    die "Input file '$filename' does not exist.";
}

if ( !-d $outputdirectory ) {
    die "Output directory $outputdirectory does not exist.";
}

if ( !-d $sourcedirectory ) {
    die "Output directory $outputdirectory does not exist.";
}

if ($format ne 'html' && $format ne 'md') {
    die "Unknown output format $format";
}

my $outputclass = 'Tools::Output';
my $templatefile = "template.$format";
# md is the default format.
if ($format ne 'md') {
    $outputclass = 'Tools::Output::' . uc ($format);
}

eval {
    # test creating this class here. dies if we don't have it
    $outputclass->new;
};
if($@) {
    die "Cannot output to format $format ($@)";
}

my $templatedir = File::Spec->catdir($Bin, 'templates', $format);
if(-d $templatedir) {
    my $templatefiles = File::Spec->catfile($templatedir, "*");
    unless ($nohelpercopy) {       
        # this won't work on Windows. 
        if ($^O eq 'MSWin32') {
            print STDERR qx(xcopy /E /Q /Y /C "$templatedir\\*" "$outputdirectory");
            unlink File::Spec->catfile($outputdirectory, "template.$format");            
        } else {
            print STDERR qx(cp -r $templatedir/* $outputdirectory);
            unlink File::Spec->catfile($outputdirectory, "template.$format");
        }
    }
    $templatefile = File::Spec->catfile($templatedir, $templatefile);
} else {
    die "Unknown template $format"
}

print STDERR "Template directory: $templatedir\n"
    if $verbose;

=head2 File parsing and index generation

=cut

## index item formatting options
our %index_options = (
    "sub"     => "show_type",
    "method"  => "show_type",
    "package" => "show_type",
    "class"   => "show_type",
    "role"    => "show_type",
    "has"     => "show_type",
    "type"    => "show_type",
    "subtype" => "show_type",
    "enum"    => "show_type",
    "global"  => "show_type",
);

## index of line numbers
our @line_index = ();

## global print options, set via comment markup
our %doc_options = ();

## create various output file names.

# windows-safety. This implies you can't have backslashes 
# as filenames. Which you shouldn't anyway.
$filename =~ s/\\/\//g;

# the title: remove leading "./" and make subfolders into packages
my $titlefilename = $filename;
$titlefilename =~ s/^\.\///;
$titlefilename =~ s/\//::/g;

# the HTML file needs to go into the same folder as all the other HTML code.
our $htmlfilename = $filename . ".$format";
$htmlfilename =~ s/^\.\///;
$htmlfilename =~ s/\//_/g;

print STDERR "Reading package index\n"
    if $verbose;

##  get the index tree for all files
## append index tree to package index
my $pindexfile = File::Spec->catfile($outputdirectory, "index.json");
my $packageindex = Tools::NamedTree->new (name => 'documenter_root');

$packageindex->value({
    title => 'Documentation Index',
    type => 'book',
    location => 0,
    anchor => "#",
    style => "h1",
    link => "index.html",
});

if (-e $pindexfile . ".storable") { 
    # local $/ = undef; 
    # local *FILE; 
    # open FILE, "<$pindexfile" and do {
    #     my $pindex = <FILE>; 
    #     close FILE;

    #     eval {
    #         $pindex = from_json($pindex);
    #         $packageindex->FROM_JSON($pindex);
    #     };
    #     if ($@) {
    #         print "[W] Invalid index.json file: $@\n";
    #     }
    # } 
    $packageindex = retrieve($pindexfile . ".storable");
};

print STDERR "Updating package index\n"
    if $verbose;

my @mypath = split /\:\:/, $titlefilename;
unshift @mypath, 'documenter_root';

my $this_node = $packageindex->has_path(\@mypath);
if(!defined $this_node) {
    $this_node = $packageindex->make_path(\@mypath, {
        title => $mypath[$#mypath],
        type => 'file',
        location => 0,
        anchor => "#",
        style => "h1",
        link => $htmlfilename,
    });
}

for (my $i = 1; $i <= $#mypath; $i++) {
    my @subpath = @mypath[0..($i-1)];
    my $path_node = $packageindex->has_path(\@subpath)
        or die "Tree node creation failed for @subpath";

    if(!defined ($path_node->value) || $path_node->value eq "") {
        $path_node->value({
            title => $mypath[$i-1],
            style => 'h1',
            type => 'folder',
        });
    }
}

print STDERR "Starting to parse\n"
    if $verbose;

## set up parsing
our $documentation = $outputclass->new;

## check if it's perl
if ($filename =~ m/\.pl$/i 
||  $filename =~ m/\.pm$/i) {
    # setup print handlers.
    Tools::PerlParser::setHandler( 'code',    \&perl_code_handler );
    Tools::PerlParser::setHandler( 'comment', \&comment_handler );
    Tools::PerlParser::setHandler( 'pod',     \&pod_handler );
    Tools::PerlParser::setHandler( 'end',     \&pod_handler );

    ## start parsing. Print handlers above will add to documentation string
    Tools::PerlParser::parse($filename);

    ## update index
    my $index_top = Tools::PerlParser::get_contents_tree();
    $index_top->traverse_update(\&index_item_info);
    $this_node->children($index_top->children);
## check if it is markdown or other stuff we can handle directly
} elsif ($filename =~ m/\.md$/
    ||   $filename =~ m/\.markdown$/
    ||   $filename =~ m/\.pod$/
    ||   $filename =~ m/\.js$/
    ||   $filename =~ m/\.html$/
    ||   $filename =~ m/README$/
    ||   $filename =~ m/LICENSE$/
    ) {
    my $md = '';
    { local $/ = undef; local *FILE; open FILE, "<", $filename
        or die "Unable to open $filename"; $md = <FILE>; close FILE }
    my $type = 'text';
    if($filename =~ m/\.([a-z0-9]+)$/i) {
        $type = lc $1;
    }

    if($type eq 'markdown') {
        $type = 'md';
    }

    # print "Documenting $filename as $type\n";
    $documentation->code($md, $type);
} else {
    die "Unknown file format for $filename";
}

## remove temp files
unlink ('pod2htmd.tmp');
unlink ('pod2htmi.tmp');

print STDERR "Processing output template\n"
    if $verbose;

## process template
my $template = Template->new({
    INCLUDE_PATH => $Bin,
    ABSOLUTE => 1,
    EVAL_PERL => 1,
    OUTPUT => File::Spec->catfile($outputdirectory, $htmlfilename),
    ENCODING => 'utf8',
});

my $vars = {
    doc => {
        TITLE => $titlefilename,
        CONTENT => $documentation->result,
    }
};

$template->process(
    $templatefile, 
    $vars,
    File::Spec->catfile($outputdirectory, $htmlfilename),
    {binmode=>'utf8'} )
    || die $template->error();

## finally, write updated index

print STDERR "Writing package index\n"
    if $verbose;

open OUT_INDEX, ">:utf8", $pindexfile
    or die "Cannot write to $pindexfile";
print OUT_INDEX to_json($packageindex->TO_JSON, {pretty=>1, allow_blessed=>1});
close OUT_INDEX;

store($packageindex, $pindexfile . ".storable");

print STDERR "Done.\n"
    if $verbose;

## all done
0;

=head1 Helper functions

Here are some helper functions for this tool.
=cut

=head2 Handler function to print source code

 Parameters:
 $current : the perl code
 $currentline : starting source line number

=cut

sub perl_code_handler {
    our $documentation;
    my $current     = shift;
    my $currentline = shift;

    # hide source
    if (defined $doc_options{'hide_source'}
        && $doc_options{'hide_source'}) {
        return;
    }

    set_current_line($currentline);

    # ignore shell env...
    $current =~ s/\#\!.*?\n//;

    # ignore stuff that only consists of whitespace.
    return if $current =~ m/^\W*$/;

    # remove trailing empty lines
    $current =~ s/(.*)\n+$/$1/g;

    # print the code
    $documentation->code($current, 'perl', $currentline);
}

=head2 Handler function to print and format PerlPod code

 Parameters:
 $current : the code

=cut

sub pod_handler {
    our $documentation;
    my $current     = shift;
    my $currentline = shift;
    set_current_line($currentline);
    $documentation->code($current, 'pod', $currentline);
}

=head2 Handler function to print and format comments

Parameters:
$current : the code
=cut

sub comment_handler {
    our $documentation;
    my $current     = encode_entities(shift);
    my $currentline = shift;
    set_current_line($currentline);

    ## here we process special markup comments.
    if ($current =~ m/^\s*hide\s+source/) {
        $doc_options{hide_source} = 1;
    } elsif ($current =~ m/^\s*show\s+source/) {
        $doc_options{hide_source} = 0;
    } else {
        $current =~ s/\n/ /g;
        $current = $documentation->b('## ') . $documentation->tt(
            $documentation->x($current) );
        $documentation->t($current);        
    }

}

=head2 get the line anchor closest to the given line

Parameters:
$lineno : the line number

Returns:
An anchor that is close to that line number.

=cut

sub get_closest_line_anchor {
    my $lineno = shift;

    our @line_index;
    my $closest_line_dist   = -1;
    my $closest_line_anchor = "#";
    foreach (@line_index) {
        my $line_dist = abs( $lineno - $_->[0] );
        my $anchor    = $_->[1];

        if (   $closest_line_dist < 0
            || $line_dist < $closest_line_dist )
        {
            $closest_line_dist   = $line_dist;
            $closest_line_anchor = "#" . $anchor;
            if ( $line_dist == 0 ) {
                last;
            }
        }
    }

    return $closest_line_anchor;
}

=head2 Function to add location info to index items.

Parameters:
$item : an index tree item

Returns:
A string with a formatted, hyperlinked item.

=cut

sub index_item_info {
    my $item = $_->[0];

    my $closest_line_anchor = get_closest_line_anchor( $item->{'location'} || 0 );
    my $options = $index_options{ $item->{'type'} };
    $options = "" if !defined($options);
    our $htmlfilename;
    my $link = $htmlfilename . $closest_line_anchor;

    $item->{anchor}  = $closest_line_anchor;
    $item->{options} = $options;
    $item->{link}    = $link;

    return $item;
}

=head2 Function to create line anchors.

 Parameters:
 $line : the current line

=cut

sub set_current_line {
    our $documentation;
    my $line = shift;
    our @line_index;

    $documentation->a("line_$line");
    push @line_index, [ $line, "line_$line" ];
}

__END__

=head1 Tool usage

=head2 Commenting guidelines

The documenter recognizes standard Perl comments, POD comments, and some
extra markup.

Here is a list of the extra rules that apply.

=over

=item *

Double comment lines: Code lines starting with ## will be added to the outline and separate
code blocks.

=item *

Function parameter descriptions: before sub's or Moose method's, pod comments may be
specified as follows:

 Parameters:
 $parameter1 : what $parameter1 does
 $parameter2 : what $parameter2 does
 ...

 Returns:
 What is returned.

Of course, you could also be more verbose.

=back

=head2 Command line usage

Code Documenter options:

 documenter.pl [options] <filename>
 Where [options] can be
 --outputdirectory <dirname> : set an output directory for the
                              generated HTML files.
							  Default value: "./"

 --sourcedirectory <dirname> : set an source directory to copy
                              styles, images, etc. from
                              This directory will default to the
							  location of documenter.pl.

 --format <html/md>          : specify the output format							  

 --index                     : make an index file, too.
