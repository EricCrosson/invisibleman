#!/usr/bin/perl
# Written by Eric Crosson
# Initial commit 29 September 2012
#
# This file is the main interface with the user (shell prompt).

use strict;
use Net::SSH2;
use Time::HiRes qw(usleep nanosleep);
# If the SSH2 package is not installed, install it with this command
# curl -L http://cpanmin.us | perl - --sudo Net::SSH2 

# Configuration - mind full pathnames
#my $username = getpwuid( $< );
my $path_to_public_key = "/home/eric/.ssh/id_rsa.pub";
my $path_to_private_key = "/home/eric/.ssh/id_rsa";
my $shell_prompt = ">> ";

# Subroutine prototypes
sub do_exit();
sub help_message();
sub prompt();
sub sleep();
sub connect();
sub disconnect();
sub print();

# Constants
# Most of these are used to store easily-typed information into the help string hash
     use constant command_not_found => "error: unrecognized command\n";
     use constant connect_help => <<END;
Usage: connect [user] [host] [alias] [public_key] [private_key]
This subroutine establishes a ssh connection to [host] using the credentials speciied by [private_key].
Disconnect from [host] with 'disconnect [host]'.
END
    use constant direct_help => <<END;
Usage: direct [host] [command]
This subroutine 'directs' the specified host to execute the specified command.
END
    use constant print_help => <<END;
Usage: print [host]
This prints the session associated with a specified host, or all hosts if invoked generically.
END
    use constant sleep_help => <<END;
Usage: sleep [microseconds]
This subroutine sleeps the system for the specified amount of microseconds.
(Actual resolution determined by the host computer.)
END
    use constant disconnect_help => <<END;
Usage: disconnect [host]
This subroutine frees the specified host from the connection database. 
END
    use constant exit_help => <<END;
This subroutine quits the Automation Scripting Tool.
END
    use constant help_dialog => <<END;
Welcome to the Automation Scripting Tool.

Here is a list of supported commands. Type 'help [command]' to get detailed information about that command. 
help\t\tshows this help message
sleep\t\tsleeps for n microseconds
connect\t\tconnects to a phone through ssh
disconnect\treleases the ssh session connecting this program and a phone
direct\t\tinstruct a host to execute a command
exit|quit\tleave the shell
END


# The hash map
# Each of the keys (command from the prompt) corresponds to a 
# subroutine containing the code to run.
my %subroutine = (    
    'help'       => \&help_message,
    'connect'    => \&connect,
    'disconnect' => \&disconnect,
    'print'      => \&search,
    'sleep'      => \&sleep,
    'exit'       => \&do_exit,
    'quit'       => \&do_exit,
    'direct'     => \&direct,
);

# Each of the connected hosts will be stored in this hash
my %clients = ();

my %helptext = (
    'help'       => "I am your best friend.\n",
    'connect'    => connect_help,
    'disconnect' => disconnect_help,
    'print'      => print_help,
    'sleep'      => sleep_help,
    'exit'       => exit_help,
    'quit'       => exit_help,
    'direct'     => direct_help,
);

# Loop to prompt the user for inputmy %helptext = (
while(1) {
    chomp(my $action = &prompt());
    my @input = split(/ /, $action);

    my $command = shift(@input);
    next unless $command;

    chomp ($command);
    if (defined $subroutine{$command}) {
	$subroutine{$command}->(@input);
    } else {
	print command_not_found;
    }
}

# Subroutines
sub do_exit() { exit @_; }

sub prompt() {
    print $shell_prompt;
    <>;
}

sub sleep() {
    usleep($_[0]);
}

# This subroutine is used only for debugging
sub search() {
    if (defined $clients{$_[0]}) {
	print $clients{$_[0]} . "\n";
    } else {
	print "The specified host was not found\n";
    }
}

# This subroutine will print a list of commands recognized by the script.
# If a specific command is included in the query, the method searches the 
# helptext hash for a command-specific string to display.
sub help_message() {
# If inquiring about a specific function, pass along the request
    if(scalar(@_) > 0) {
	chomp(my ($command) = $_[0]);
	if (defined $helptext{$command}) {
	    print $helptext{$command};
	} else {
	    print command_not_found;
	}
	return;
    } # Otherwise, just display the generic dialog
    print help_dialog;
}

sub connect() {
    # Return if no host
    if (scalar(@_) lt 1) {
	return;
    }
    my ($username, $host, $alias, $public_key, $private_key) = @_;
    $alias = $host unless $alias;
    $public_key = $path_to_public_key unless $public_key;
    $private_key = $path_to_private_key unless $private_key;

    my $ssh2 = Net::SSH2->new();
    $ssh2->connect($host) or die "Unable to connect to host $host\n";
    if (!$ssh2->auth_publickey($username, $public_key, $private_key) ) {
	warn "Authorization failed on host $host.\nHere is what I know:\n" . 
	    "user:$username\nhost:$host\npub_key:$public_key\npriv_key:$private_key";
	return;
    }

    $clients{$alias} = $ssh2;
}

#TODO-make this work
sub direct() {
    my ($alias) = shift;
    if (!defined $clients{$alias}) { #If the host isn't found, can't do anything.
	print "Specified host not found! Have you connected him yet?\n";
	    return;
    }

    my ($command) = '';
    foreach (@_) { $command .= $_ . ' '; } #TODO append in perl? then init to \n
    $command .= "\n"; # Now $command contains the string to execute

    die unless defined (my $ssh = $clients{$alias});
    $ssh->debug(1);
    my $chan = $ssh->channel();
    $chan->shell();
    $chan->blocking(0);  # Allow commands to be passed to the shell
    #print $chan $command;
    $chan->exec('ls -lAh /home/eric/\n');
    print "LINE : $_" while <$chan>;

    $chan->blocking(1);  # Re-block for storage
    $chan->close();
}

#TODO-make this work
sub disconnect() {
}

