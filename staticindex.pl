#!/usr/bin/perl
=head1 Static Index Generator

Generates a static index from Documenter index JSON

=cut

use strict;

use FindBin qw($Bin);
use lib "$Bin";

use JSON;
use File::Basename;
use File::Spec qw(catfile);
use XML::RSS;
use Scalar::Util qw(looks_like_number);
use DateTime;
use DateTime::Format::W3CDTF;
use DateTime::Format::Epoch;
use Template;

use Tools::Output;
use Tools::Output::HTML;

use sort 'stable';

if (!defined $ARGV[0]) {
	die "Usage : staticindex.pl <indexfilename> <baseurl=http://localhost:4000/> <flat_type=html>";
}

my $baseurl = $ARGV[1] || "http://localhost:4000/";

my $flat_index_type = (lc $ARGV[2]) || 'html';

unless ($baseurl =~ m/\/$/) {
 	$baseurl .= '/';
}

my $js;
{ local $/ = undef; local *FILE; 
	open FILE, "<", $ARGV[0]; $js = <FILE>; close FILE }

my $f_base = basename($ARGV[0]), "\n";
my $f_dir  = dirname($ARGV[0]), "\n";

my $indexdata = from_json($js);

our @linear_index = ();

recurse($indexdata);

=head2 Sorting comparator by index id

Used for sort, compares two index ids:
 
 1.2.3 < 1.2.4
 1.2 < 1.2.4
 1.2.3 = 1.2.3
 2.0 > 1.9.9
 1.11 > 1.1
 etc.

=cut

sub by_idx {
	my $a = shift;
	my $b = shift;
	my $result = 0;
	my @a_s = split /\./, $a->{linear_index_pos};
	my @b_s = split /\./, $b->{linear_index_pos};

	my $len = scalar @a_s;
	if (scalar @b_s < $len) {
		$len = scalar @b_s;
	}

	for (my $i = 0; $i < $len; $i++) {
		if ($a_s[$i] ne $b_s[$i]) {
			if (looks_like_number ($a_s[$i]) && 
				looks_like_number ($b_s[$i]) ) {
				return $a_s[$i] <=> $b_s[$i];
			} else {
				return $a_s[$i] cmp $b_s[$i];
			}
		}
	}

	# here, all elements in a_s and b_s were the same
	# check which one of them is shorter
	if (scalar @b_s < scalar @a_s) {
		return -1;
	}
	if (scalar @a_s < scalar @b_s) {
		return 1;
	}

	# equal elements, return;
	return 0;
}

=head2 Recursively process the index tree

 Parameters:
 $node 		: the current node (hash with value and children elements)
 $path 		: the current path (used in recursion)
 $level		: the current depth
 $index_pos	: the parent's index position

=cut

sub recurse {
	my $node = shift;
	my $path = shift || "Index";
	my $level = shift || 1;
	my $index_pos = shift || '1';

	my $filename = $node->{value}->{link};
	# remove hash tag
	$filename =~ s/\#.*$//;
	$filename =~ s/\.html$//;

	$node->{value}->{path}  = $path . "/" . $filename;
	$node->{value}->{level} = $level;

	$node->{value}->{linear_index_pos} = $index_pos;
	$node->{value}->{linear_index_pos} =~ s/[^A-Za-z0-9\.\-\_]/\_/g;

	push @linear_index, $node->{value}
		if defined ($node->{value}->{link}) && $node->{value}->{link} ne "";

	# default order is lexicographically by path, 
	# but we can prioritize items using index_path
	# which is set using markup comments (see PerlParser.pm)
	my @ordered_children = sort {
			my $pa = $a->{value}->{index_path} || $a->{path};
			my $pb = $b->{value}->{index_path} || $b->{path};
			return $pa cmp $pb
		} 	@{$node->{children}};

	my $sub_index = 1;
	foreach my $c (@ordered_children){
		recurse($c, $node->{path}, $level + 1, 
			$index_pos . '.' . $sub_index);
		$sub_index++;
	}
	# establish index order
	@ordered_children = sort { by_idx($a->{value}, $b->{value}) } @ordered_children;
	$node->{children} = \@ordered_children;
}

## write updated index
open OUT_INDEX, ">", $ARGV[0]
	or die "Cannot update index with order information\n";

print OUT_INDEX to_json($indexdata, {pretty=>1});

close OUT_INDEX;

print "Number of items: ", scalar @linear_index, "\n";

# create an RSS 2.0 file

my $dt = DateTime->new( year => 1970, month => 1, day => 1 );

my $parser = DateTime::Format::Epoch->new(
                      epoch          => $dt,
                      unit           => 'seconds',
                      type           => 'int',    # or 'float', 'bigint'
                      skip_leap_seconds => 1,
                      start_at       => 0,
                      local_epoch    => undef,
                  );
my $formatter = DateTime::Format::W3CDTF->new;

my $rss = XML::RSS->new (version => '2.0');
$rss->channel(title          => 'Source Index',
              link           => $baseurl,
              language       => 'en',
              description    => 'Source documentation',
              pubDate        => $formatter->format_datetime(DateTime->now),
              lastBuildDate  => $formatter->format_datetime(DateTime->now),
     );

# index order sorting
sort {by_idx($a, $b)} @linear_index;

my $flat_output;

if ($flat_index_type eq 'html') {
	$flat_output = Tools::Output::HTML->new;
} else {
	$flat_output = Tools::Output->new;
}

foreach my $e (@linear_index) {
	my $filename = $e->{link};
	# remove hash tag
	$filename =~ s/\#.*$//;

	$filename = File::Spec->catfile($f_dir, $filename);
	my $mod = $formatter->format_datetime(
		$parser->parse_datetime( (stat "$filename")[9] )
		);


	my $vstr = $flat_output->l($flat_output->x($e->{title}), $e->{link});

	if($e->{options} =~ m/show\_type/) {
		$vstr = $e->{type} . ' ' . $vstr;
	}

	$flat_output->xt($e->{linear_index_pos});
	$flat_output->t(
		"&nbsp;" . $flat_output->b(
				$vstr
			)
		);

	$flat_output->t(
		"&nbsp; (" . $flat_output->i(
				$flat_output->x($e->{path})
			) 
		. ")"
		);

	$flat_output->p();

	$rss->add_item(title => $e->{title},
	       # creates a guid field with permaLink=true
	       permaLink  => $baseurl . $e->{link},
	       description => 
	       	$e->{type} . ":" . 
	       	$e->{level} . ":" . 
	       	$e->{linear_index_pos} . ":" .
	       	$e->{path},
	       dc => { 
              date => $mod
           },
	);
}

$rss->save(File::Spec->catfile($f_dir, 'feed.rss'));

## make a static index file
## process template
my $template = Template->new({
    INCLUDE_PATH => $Bin,
    ABSOLUTE => 1,
    EVAL_PERL => 1,
    OUTPUT => File::Spec->catfile($f_dir, 'static_index.'.$flat_index_type),
    ENCODING => 'utf8',
});

my $vars = {
    doc => {
        TITLE => "Documentation Index",
        CONTENT => $flat_output->result,
    }
};

my $templatefile = "template.$flat_index_type";
my $templatedir = File::Spec->catdir($Bin, 'templates', $flat_index_type);
$templatefile = File::Spec->catfile($templatedir, $templatefile);

$template->process (
    $templatefile, 
    $vars,
    File::Spec->catfile($f_dir, 'static_index.'.$flat_index_type),
    {binmode=>'utf8'} )
    || die $template->error();

