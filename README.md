The Perl+Moose Documentation Generator
======================================

This is a simple documentation tool for source code. It is a prototype which
currently supports Perl (+Moose).

We generate HTML page from source code, and create a searchable index. This
index contains elements both generated from documentation and from some basic
code-intelligence (we recognize functions, classes, packages, etc).

Mainly, this was made to make code documentation as easy as possible. We do
not use any special markup for parameters and such, and the amount of comments
required in the source files is rather minimal. To make things easier to read
however, it is a good idea to write code with good structure.

So, here is how some Moose code looks.

```perl

use MooseX::Declare;

=head1 Some class doing stuff in Perl

=cut

class MyClass {

=head2 This method does cool things.

 Parameters: $i : A number

 Returns: That number $i, incremented.

=cut 

method some_method(Int $i) { return $i + 1; } }

```

This is what this tool does:

* It associates the first head1 with the package/class `MyClass`.
* head2 and double-hash elements are connected to the method/declaration
  below.
* We recognize some markup (or markdown, or pod) for formatting and links

Using the recursivedocumenter script, this can be done recursively for a set
of modules. The generated index then allows searching across a bigger set of
source files.

Finally, it's self-documenting: see [http://pkrusche.github.com/documenter].

Dependencies
------------

**Javascript/HTML:** 

* [jQuery](http://jquery.com/) and [jQueryUI](http://jqueryui.com/)
* [highlight.js](http://softwaremaniacs.org/soft/highlight/en/)
* The [famfamfam silk icons](www.famfamfam.com/lab/icons/)
* optionally: [redcarpet](http://rubygems.org/gems/redcarpet) (for more
  github-like [markdown](http://daringfireball.net/projects/markdown/)
  rendering). 
  You can install it by running `gem install redcarpet` if you have Ruby.

**Perl:** 

The follwing Perl modules are required. You can install them via CPAN (run `cpan`, then
`install <modulename>` for each of the modules shown below), or
using apt if you're on Ubuntu.

The template toolkit (used to process HTML and MD templates)

*  [Template ](http://search.cpan.org/search?mode=all&query=Template )

Things for [markdown](http://daringfireball.net/projects/markdown/) rendering:

*  [Perl::Markdown](http://search.cpan.org/search?mode=all&query=Perl::Markdown)
*  [Pod::Markdown](http://search.cpan.org/search?mode=all&query=Pod::Markdown)
*  [Text::Markdown](http://search.cpan.org/search?mode=all&query=Text::Markdown)

The Perl Parser Interface: 

*  [PPI ](http://search.cpan.org/search?mode=all&query=PPI )
*  [PPI::Dumper](http://search.cpan.org/search?mode=all&query=PPI::Dumper)
*  [PPI::Find](http://search.cpan.org/search?mode=all&query=PPI::Find)

Moose and MooseX (installing MooseX::Declare installs everything necessary)

*  [MooseX::Declare ](http://search.cpan.org/search?mode=all&query=MooseX::Declare )

This stuff is used for rendering the RSS feed.

*  [URI::Escape](http://search.cpan.org/search?mode=all&query=URI::Escape)
*  [DateTime ](http://search.cpan.org/search?mode=all&query=DateTime )
*  [DateTime::Format::Epoch ](http://search.cpan.org/search?mode=all&query=DateTime::Format::Epoch )
*  [XML::RSS ](http://search.cpan.org/search?mode=all&query=XML::RSS )
*  [DateTime::Format::W3CDTF](http://search.cpan.org/search?mode=all&query=DateTime::Format::W3CDTF)
*  [HTML::Entities](http://search.cpan.org/search?mode=all&query=HTML::Entities)

Others:

*  [Parse::RecDescent](http://search.cpan.org/search?mode=all&query=Parse::RecDescent)
*  [File::Which](http://search.cpan.org/search?mode=all&query=File::Which)
*  [JSON](http://search.cpan.org/search?mode=all&query=JSON)
