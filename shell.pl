#!/usr/bin/perl
use strict;

use Time::HiRes qw(usleep nanosleep);
use Net::SSH2;
# If the SSH2 package is not installed, install it with this command
# curl -L http://cpanmin.us | perl - --sudo Net::SSH2 

# Written by Eric Crosson
# Initial commit 29 September 2012
#
# This file is the main interface with the user (shell prompt).

# Subroutine prototypes
sub do_exit();
sub help_message();
sub prompt();
sub sleep();
sub connect();
sub disconnect();
sub print();

# Constants
use constant command_not_found => "error: unrecognized command\n";

# The hash map
# Each of the keys (command from the prompt) corresponds to a 
# subroutine containing the code to run.
my %subroutine = (    
    'help'       => \&help_message,
    'connect'    => \&connect,
    'disconnect' => \&disconnect,
    'print'      => \&print,
    'sleep'      => \&sleep,
    'exit'       => \&do_exit,
    'quit'       => \&do_exit,
);

my %clients = ();

# Loop to prompt the user for input
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
	print command_not_found;
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
# If inquiring about a specific function, pass along the request
	my ($command) = $_[0];
	chomp($command);
	if (defined $subroutine{$command}) {
	    $subroutine{$command}->("help");
	} else {
	    print command_not_found;
	}
    } else {
print<<END;
Welcome to the Automation Scripting Tool.

Here is a list of supported commands. Type 'help [command]' to get detailed information about that command. 
help\t\tshows this help message
sleep\t\tsleeps for n milliseconds
connect\t\tconnects to a phone through ssh
disconnect\treleases the ssh session connecting this program and a phone
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

#TODO-make this work
sub connect() {
    if($_[0] eq "help") {
print<<END;
Usage: connect [host] [private_key]
This subroutine establishes a ssh connection to [host] using the credentials speciied by [private_key].
Disconnect from [host] with 'disconnect [host]'.
END
	return;
    }
    my $ssh2 = Net::SSH2->new();
    $ssh2->connect($_[0]) or print "Unable to connect to $_[0]" && return;

    print "(optional) Enter an alias for this host: ";
    my $alias = <>;
    chomp($alias);
    if (length($alias) <= 0) { # If alias declined
	$alias = $_[0];
    }

    $clients{$alias} = $ssh2;
}

#TODO-make this work
sub disconnect() {
    if($_[0] eq "help") {
print<<END;
Usage: disconnect [host].
This subroutine disconnects from [host], provided a connection has already been established.
END
	return;
    }
}

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

# This subroutine is used only for debugging
sub print() {
    if($_[0] eq "help") {
print<<END;
Usage: print [host]
This prints the session associated with a specified host, or all hosts if invoked generically.
END
	return;
    }
    if (defined $clients{$_[0]}) {
	print $clients{$_[0]};
	print "\n";
    } else {
	print "The specified host was not found";
    }
}
