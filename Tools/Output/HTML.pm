#!/usr/bin/perl

use MooseX::Declare;

=head1 HTML Output Package

 HTML Output implementation

=cut

class Tools::Output::HTML extends Tools::Output {
    use HTML::Entities;
    use URI::Escape;
    use Data::Dumper;
    use JSON;
    use File::Temp qw(tempfile);
    use Tools::CommentSpecials qw(markdown_specials);

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
        $self->{result}.= "<hr/>";
    }

    ## append a line break
    method br() {
        $self->{result}.= "<br/>";
    }

    ## append a par
    method p() {
        $self->{result}.= "<p/>";
    }

=head2 Decorators

Decorator functions add markup to the text passed and return the result.

=cut

    ## headings
    method h(Str $text, Int $level?) {
        $level ||= 1;
        return "<h$level>".$self->x($text)."</h$level>";
    }

    ## boldface
    method b (Str $text ) {
        return "<strong>${text}</strong>";
    }

    ## italic/emph
    method i(Str $text ) {
        return "<em>$text</em>";
    }

    ## tt font
    method tt(Str $text) {
        return "<span class=\"monospaced\">$text</span>";
    }

    ## escape text
    method x($text) {
        return encode_entities($text);
    }

    ## make an anchor.
    method a($name) {
        $name =~ s/\"/_/g;
        $self->{result}.= "<a name=\"$name\" />";
    }

    ## make a link.
    method l($text, $link) {
        return "<a href=\"$link\">$text</a>";
    }

    ## assign some style
    method style($text, $style) {
        return "<span style=\"$style\">$text</span>";
    }

=head2 Pretty-print code

(we use Perl code pretty printing)

 Parameters:
 $code : the code
 $type : the type of code (perl/pod/md/...)

=cut
    method code(Str $code, Str $type?, Str $startline?) {
        $startline ||= 1;

        if ($type eq 'pod') {
            my ($fh, $fn) = tempfile;
            print $fh $code;
            close $fh;
            my $parser = Pod::Markdown->new;
            $parser->parse_from_file($fn);
            $self->code($parser->as_markdown, 'md');
        } elsif ($type eq 'md') {
            use File::Which qw(where);

            $code = markdown_specials($code);

            ## we prefer redcarpet because it does 
            ## fenced code blocks and extensions
            my @rc = where('redcarpet');
            if (scalar @rc == 0) {
                # print "[I] Using Text::Markdown for markdown rendering\n";
                use Text::Markdown 'markdown';
                $self->t(markdown($code));
            } else {
                # print "[I] Using $rc[0] for markdown rendering\n";
                my ($fh, $fn) = tempfile;
                print $fh $code;
                close $fh;
                my $mdtext = `"$rc[0]" --parse-fenced_code_blocks --parse-superscript --parse-no_intra_emphasis --smarty $fn`;
                $self->t($mdtext);
            }

        } else {
            my $class = "";
            if (defined $type) {
                $class = "class=\"$type\"";
            }

            # remove newlines
            $code=~ s/^[\s\n\r\t]+//;
            $code=~ s/[\s\n\r\t]+$//;

            $self->{result} .= "<div class=\"code\"><pre><code $class>";
            $self->{result} .= encode_entities($code);
            $self->{result} .= "</code></pre></div>";
        }
    }


}
