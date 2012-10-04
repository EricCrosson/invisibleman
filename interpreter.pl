#!/usr/bin/perl
use Iterator::File::Line;

# Subroutines
sub process_line();

my $i = Iterator::File::Line->new(
    filename => 'first.auto',
    chomp => 0,
    );

while ( my $line = $i->next ) {
    local $_;
    if ( $line =~ m/{/ ) { # if loop::start
	(my $rep = $line) =~ s/\D//g;

	my @commands;
	until ( (my $loop = $i->next) =~ m/}/ ) {
	    push @commands, $loop;
	}
	for(my $c = 0; $c < $rep; $c++) {
	    &process_line($_) foreach (@commands);
	}
    } else {
	print $line;
    }
}

sub process_line() {
    my ($line) = @_;
    print $line;
}
