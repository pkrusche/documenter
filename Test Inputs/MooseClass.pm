#!/usr/bin/perl
use strict;
use MooseX::Declare;

=head1 Some class doing stuff in Perl

In this class, we do some crazy Moose stuff.

=cut

class MooseClass {

=head2 This method does cool things.

B<Here's some Moose trivia:>

Remember to always keep the method declaration in one line, 
like this:
 
 method some_method(Int $i) { ...

NEVER MOVE THE OPENING BRACKET OR PARAMETERS TO THE NEXT LINE.

 method some_method(Int $i) 
 { ...

Otherwise, bad things happen in Moose-land.

 Parameters:
 $i : A number

 Returns:
 That number $i, incremented.

=cut
	method some_method(Int $i) {
		## This is where we increment $i
		## Also, double-hash comments split code into sections with
		## an anchor
		return $i + 1;
	}

## hide source

=head2 Hiding Source Code

Sometimes, we might not want to show all code in the documentation.
This is achieved using the 

 ## show source 

and 

 ## hide source 

comments.

=cut

	method not_necessary_to_show_code() {
		# ... code which would confuse readers.
	}

## show source
	
	## this method is shown including source
	method shown() {
		# this method will be shown in documentation
	}

}
