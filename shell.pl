#!/usr/bin/perl
use strict;
use warnings;

# Written by Eric Crosson
# 29 September 2012
#
# This file is the main interface with the user (shell prompt).

# Subroutine prototypes
sub do_exit();
sub help_message();
sub connect();
sub sleep();
sub prompt();

my %subroutine = (    
    'help'    => \&help_message,
    'connect' => \&connect,
    'sleep'   => \&sleep,
    'exit'    => \&do_exit,
    'quit'    => \&do_exit,
);


while(1==1) {
    my $action = &prompt();
    my @input = split(/ /, $action);

    my $sub = shift(@input);
    chomp ($sub);
    if (defined $subroutine{$sub}) {
	$subroutine{$sub}->(@input);
    } else {
	print "error: unrecognized command\n";
    }
}

# Subroutines
sub prompt() {
    print ">> ";
    <>;
}

sub help_message() {
if(scalar(@_) > 1) {
    my ($command) = @_;

} else {
print<<END;
Welcome to the Automation Scripting Tool.

Here is a list of supported commands. Type 'help [command]' to get detailed information about that command. 
help\t\tshows this help message
sleep\t\tsleeps for n milliseconds
connect\t\tconnects to a phone through ssh
exit|quit\tleave the shell
END
}
}

sub do_exit() {
    print "Exiting...\n";
    exit 0;
}

sub connect() {
}

sub sleep() {
}
