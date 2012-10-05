#!/usr/bin/perl
# Written by Eric Crosson
# Initial commit 29 September 2012
#
# This file is the main interface with the user (shell prompt).

# If the utilized packages aren't installed, install them with
# curl -L http://cpanmin.us | perl - --sudo Net::SSH2 
use strict;
use Net::SSH2;
use Tie::File;
use Fcntl "O_RDONLY";
use Time::HiRes "usleep";

# Configuration - mind full pathnames
my $shell_prompt = ">> ";
my %ssh = (
    'username' => getpwuid( $< ), #admin
    'pub'      => "/home/eric/.ssh/id_rsa.pub",
    'priv'     => "/home/eric/.ssh/id_rsa",
);

# Subroutine prototypes
sub do_exit();
sub help_message();
sub prompt();
sub sleep();
sub config();
sub connect();
sub disconnect();
sub print();
sub parsefile();
sub processCommand();

# Help messages, defined outside of program for readability
     use constant command_not_found => "error: unrecognized command";
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
    use constant config_help => <<END;
Usage: config [username] [public key] [private key]
This subroutine allows for changing of ssh options during runtime.
END


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
    'config'     => \&config,
    'run'        => \&parsefile,
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
    'config'     => config_help,
);

my @file;

# Loop to prompt the user for input
while(1) {
    chomp(my $action = &prompt());
    (my $command = $action) =~ /^(.*?)\s/; # first word
    &processCommand($action);
}

sub processCommand() {
    my @input = split(/ /, $_[0]);
    chomp(my $command = shift(@input));
    return unless $command; # prevents error on blank commands

    if (defined $subroutine{$command}) {
	$subroutine{$command}->(@input);
    } elsif (-e $command) {
	&parsefile($command);
    } else {
	print command_not_found . " $command\n";
    }
}

# Subroutines
sub do_exit() { exit @_; }

sub sleep() { usleep($_[0]); }

sub prompt() {
    print $shell_prompt;
    <>;
}

# This subroutine is used only for debugging. If an alias is specified,
# print information about that alias. Else, list the entire directory.
# Args: [list of names]
sub search() {
    if (scalar (@_) eq 0) {
	while (my ($alias, $instance) = each(%clients)) {
	    print "$alias: $instance\n";
	}
	return;
    }
    foreach (@_) {
	if (defined $clients{$_}) {
	    print "$_ = $clients{$_}\n";
	} else {
	    print "$_ was not found\n";
	}
    }
}

# This subroutine allows for changing of ssh options during runtime.
# The ssh connection will use these settings for authentication. 
# Args: [username] [path to public key] [path to private key]
sub config() {
    chomp(my ($user, $pubK, $privK) = @_);
    $ssh{'username'} = $user if defined $user;
    $ssh{'pub'} = $pubK if defined $pubK;
    $ssh{'priv'} = $privK if defined $privK;
    print "Current configuration:\nusername:$ssh{'username'}\n" .
	"pub:$ssh{'pub'}\npriv:$ssh{'priv'}\n";
}

# This subroutine will print a list of commands recognized by the script.
# If a specific command is included in the query, the method searches the 
# helptext hash for a command-specific string to display.
# Args: [command]
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

# This subroutine will establish a connection to the specified host, storing
# the resulting object in a hash. In this way, we can name our connections
# in a human-readable manner, and send them commands and gather output with ease.
# Args: [host] [alias]
sub connect() {
    return if (scalar(@_) lt 1);

    chomp(my ($host, $alias) = @_);
    $alias = $host unless $alias;

    my $ssh2 = Net::SSH2->new();
    $ssh2->connect($host) or warn "Unable to connect to host $host\n";
    if (!$ssh2->auth_publickey($ssh{'username'}, $ssh{'pub'}, $ssh{'priv'})) {
	warn "Authorization failed on host $host.";
	return;
    }

    $clients{$alias} = $ssh2;
}

# This subroutine forwards a directive to the specified host as a string.
# Args: [alias] [command]
sub direct() {
    my ($alias) = shift;
    if (!defined $clients{$alias}) { #If the host isn't found, can't do anything.
	print "Specified host not found! Have you connected him yet?\n";
	    return;
    }

    my ($command) = ''; # let $command contains the string to execute
    foreach (@_) { $command .= $_ . ' '; }

    my $ssh = $clients{$alias};
    my $chan = $ssh->channel();
    $chan->shell();
    $chan->blocking(0);  # Allow commands to be passed to the shell
    print $chan $command . "\n";
    print $_ while <$chan>;
    $chan->blocking(1);  # Re-block for storage
}

# This subroutine disconnects from a specified host and frees associated memory.
# Args: [list of aliases to disconnect]
sub disconnect() {
    foreach (@_) {
	next unless defined $clients{$_};
	$clients{$_}->disconnect();
	delete $clients{$_};
    }
}

# This subroutine begins the recursive parsing of the supplied file.
# Args: [file to parse]
sub parsefile() {
    chomp(my ($file) = @_);
    tie @file, 'Tie::File', "$file", mode => O_RDONLY, memory => 35_000_000;
    &run_block(1, 0); # Run the main code block, once
}

# This is a recursive subroutine.
# This subroutine will read each line in a block of code (each loop is one block)
# and execute the desired instructions. Each nested loop recurses once. 
# Args: [times to repeat] [line to start parsing]
sub run_block() {
    my ($rep, $line) = @_;
    my $i = 1, my $initial = $line, my $final;
    for($i; $i <= $rep; $i++) {
	while ($line < scalar(@file)) {

# If a loop is starting, parse the number of times to repeat
# and jump in.
	    if ($file[$line] =~ m/{/) { 
		(my $inner_rep = $file[$line]) =~ s/\D//g;
		$line = &run_block($inner_rep, $line+1);
	    }
# If we have reached a closing brace, a loop is ending. Reset the 
# program counter and repeat from the beginning.
	    elsif ($file[$line] =~ m/}/) { 
		$final = $line unless $final;
		$line = $initial;
		last;
	    }
# If not a control statment, this must be a command. Run as such.
	    else { &processCommand($file[$line]); }
	    $line++;
	}
    }
    return $final; # Return where inner loop ends for the encompassing loop
}
