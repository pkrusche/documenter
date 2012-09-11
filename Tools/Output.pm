#!/usr/bin/perl

use MooseX::Declare;

=head1 Abstraction class for outputting pretty-printed stuff

 Default implementation returns markdown-style things.

=cut

class Tools::Output {
	require Tools::Tree;
	use Pod::Markdown;
	use File::Temp qw(tempfile);
    use HTML::Entities;
    use Tools::CommentSpecials qw(markdown_specials);
	
	## The resulting text
	has 'result' => (
		is => 'rw',
		isa => 'Str',
		default => "",
	);

=head2 Append text and other things to output

=cut
	
	## append text
	method t( Str $text ) {
		$self->{result}.= $text;
	}

	## append escaped text
	method xt( Str $text ) {
		$self->{result}.= $self->x($text);
	}

	## append a hrule
	method hr() {
		$self->{result}.= "\n\n---------------------------------------\n\n";
	}

    ## append a line break
    method br() {
        $self->{result}.= " \n";
    }

    ## append a par
    method p() {
        $self->{result}.= "\n\n";
    }

=head2 Decorators

Decorator functions add markup to the text passed and return the result.

=cut

	## headings
	method h(Str $text, Int $level?) {
		my $return = "";
		$level ||= 1;

		for (my $i = 0; $i < $level; $i++) {
			$return.= '# ';
		}

		$return .= $self->x($text) . "\n\n";

		return $return;
	}

	## boldface
	method b (Str $text ) {
		return "__${text}__";
	}

	## italic/emph
	method i(Str $text ) {
		return "*$text*";
	}

	## tt font
	method tt(Str $text) {
		return "\`$text\`";
	}

	## escape text
	method x($text) {
## from http://daringfireball.net/projects/markdown/syntax#backslash
# \   backslash
# `   backtick
# *   asterisk
# _   underscore
# {}  curly braces
# []  square brackets
# ()  parentheses
# #   hash mark
# +   plus sign
# -   minus sign (hyphen)
# .   dot
# !   exclamation mark
		$text = encode_entities($text);
		$text =~ s/([\\\`\*\_\{\}\[\]\(\)\#\+\-\.\!])/\\$1/g;
		return $text;
	}

	## make an anchor. Markdown doesn't do that.
	method a($name) {
		return "";
	}

	## make a link.
	method l($text, $link) {
		return "[$text]($link)";
	}

	## assign some style (MD: does nothing)
	method style($text, $style) {
		return $text;
	}

=head2 Pretty-print code

(we use github-style rather than <code> type things)

 Parameters:
 $code : the code
 $type : the type of code (perl/pod/md...)
 $startline: the starting line number

=cut

	method code(Str $code, Str $type?, Str $startline?) {
		if (!defined $type) {
			$self->{result}.= "\n{% highlight text %}\n$code\n{% endhighlight %}\n";
		} else {
			if ($type eq 'pod') {
				my ($fh, $fn) = tempfile;
				print $fh $code;
				close $fh;
				my $parser = Pod::Markdown->new;
				$parser->parse_from_file($fn);
				$self->code ($parser->as_markdown, 'md');
			} elsif ($type eq 'md') {
				$self->t("\n" . markdown_specials($code) );
			} else {
	            # remove newlines
	            $code=~ s/^[\s\n\r\t]+//;
	            $code=~ s/[\s\n\r\t]+$//;
				$self->{result}.= "\n{% highlight $type %}\n$code\n{% endhighlight %}\n"
			}
		} 
	}

};
