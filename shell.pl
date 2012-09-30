#!/usr/bin/perl
use strict;

use Time::HiRes qw(usleep nanosleep);

# Written by Eric Crosson
# 29 September 2012
#
# This file is the main interface with the user (shell prompt).

# Subroutine prototypes
sub do_exit();
sub help_message();
sub connect();
sub disconnect();
sub sleep();
sub prompt();

my %subroutine = (    
    'help'       => \&help_message,
    'connect'    => \&connect,
    'disconnect' => \&disconnect,
    'sleep'      => \&sleep,
    'exit'       => \&do_exit,
    'quit'       => \&do_exit,
);


while(1==1) {
    my $action = &prompt();
    chomp($action);
    my @input = split(/ /, $action);

    my $command = shift(@input);
#    @input = (" ") if (scalar(@input) eq 0);

    chomp ($command);
    if (defined $subroutine{$command}) {
	$subroutine{$command}->(@input);
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
    if($_[0] eq "help") {
	print "Not much to say about this command!\n";
	return;
    }
    
    if(scalar(@_) > 0) {
	my ($command) = $_[0];
	chomp($command);
	if (defined $subroutine{$command}) {
	    $subroutine{$command}->("help");
	} else {
	    print "error: unrecognized command\n";
	}
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
    if($_[0] eq "help") {
	print "This subroutine quits the Automation Scripting Tool.\n";
	return;
    }

    print "Exiting...\n";
    exit 0;
}

sub connect() {
    if($_[0] eq "help") {
print<<END;
Usage: connect [host] [private_key]
This subroutine establishes a ssh connection to [host] using the credentials speciied by [private_key].
Disconnect from [host] with 'disconnect [host]'.
END
	return;
    }
	
}

sub disconnect() {
    if($_[0] eq "help") {
print<<END;
Usage: disconnect [host].
This subroutine disconnects from [host], provided a connection has already been established.
END
	return;
    }
}

#TODO- make this functional
sub sleep() {
    if($_[0] eq "help") {
print<<END;
Usage: sleep [ms]
This subroutine sleeps for the desired number of microseconds.
(Actual resolution determined by host computer)
END
	return;
    }
    usleep($_[0]);
}
