#!/usr/bin/perl
use strict;
use Tie::File;
use Fcntl 'O_RDONLY';

tie my @file, 'Tie::File', 'first.auto', mode => O_RDONLY, memory => 35_000_000;
&run_block(1, 0); # Run the main code block, once.

# This is a recursive subroutine! Each loop will call another layer of recursion.
# Args: [times to repeat] [line to start parsing]
sub run_block() {
    local $_;
    my ($rep, $line) = @_;

    my $i = 1;
    my $initial = $line;
    my $final;
    for($i; $i <= $rep; $i++) {

	while ($line < scalar(@file)) {

	    if ($file[$line] =~ m/{/) { #If a loop is starting
		(my $inner_rep = $file[$line]) =~ s/\D//g;
		$line = &run_block($inner_rep, $line+1);
	    }
	    
	    elsif ($file[$line] =~ m/}/) { #If a loop is ending
		$final = $line unless $final;
		$line = $initial;
		last;
	    }
	    
	    else { # Just run a command
		print $file[$line] . "\n";
	    }
	    $line++;
	}
    }
    return $final;
}
