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
    username => getpwuid( $< ), #admin
    pub      => "/home/eric/.ssh/id_rsa.pub",
    priv     => "/home/eric/.ssh/id_rsa",
);

# Help messages, defined outside of program for readability
     use constant command_not_found => "error: unrecognized command";
     use constant connect_help => <<END;
Usage: connect [user] [host] [alias] [public_key] [private_key]
This subroutine establishes a ssh connection to [host] using
the credentials speciied by [private_key].
Disconnect from [host] with 'disconnect [host]'.
END
    use constant direct_help => <<END;
Usage: direct [host] [command]
This subroutine 'directs' the specified host to execute the specified command.
END
    use constant print_help => <<END;
Usage: print [list of hosts]
This prints the session associated with a specified host,
or all hosts if invoked generically.
END
    use constant sleep_help => <<END;
Usage: sleep [microseconds]
This subroutine sleeps the system for the specified amount of microseconds.
(Actual resolution determined by the host computer.)
END
    use constant disconnect_help => <<END;
Usage: disconnect [list of hosts]
This subroutine frees the specified host from the connection database. 
END
    use constant exit_help => <<END;
This subroutine quits the Automation Scripting Tool.
END
    use constant help_dialog => <<END;
Welcome to the Automation Scripting Tool.

Here is a list of supported commands.
Type 'help [command]' to get detailed information about that command. 
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
    'sleep'      => \&usleep,
    'exit'       => \&do_exit,
    'quit'       => \&do_exit,
    'direct'     => \&direct,
    'config'     => \&config,
    'run'        => \&parsefile,
);

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

my %clients = ();
my @file;

# Main loop to prompt the user for input.
while(1) {
    chomp(my $action = &prompt());
    (my $command = $action) =~ /^(.*?)\s/; # first word
    &processCommand($action);
}

# This subroutine directs input to where it needs to go. Files are parsed,
# methods are invoked, or an error is thrown. 
sub processCommand() {
    chomp(my @input = split(/ /, $_[0]));
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
# Wrapper for the exit function. This allows for error codes
sub do_exit() { exit @_; }

# This subroutine prints the configured string to ask for input and returns a command
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
    $ssh{username} = $user if defined $user;
    $ssh{pub} = $pubK if defined $pubK;
    $ssh{priv} = $privK if defined $privK;
    print "Current configuration:\nusername:$ssh{username}\n" .
	"pub:$ssh{pub}\npriv:$ssh{priv}\n";
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
    if (!$ssh2->auth_publickey($ssh{username}, $ssh{pub}, $ssh{priv})) {
	warn "Authorization failed on host $host.";
	return;
    }

    $clients{$alias} = $ssh2;
}

# This subroutine forwards a directive to the specified host as a string.
# If one wishes to send more than just one string, specify a file with 
# a list of commands (minus the 'direct [alias]'. This file will be parsed
# and each line will be sent to the target computer. 
# Args: [alias] [command|file]
sub direct() {
    my ($alias) = shift;
    if (!defined $clients{$alias}) { 
	print "Specified host not found! Have you connected him yet?\n";
	    return;
    }

# If we have a file on our hands: parse it, prepending each line 
# (save control structures) with the phrase 'direct [alias]'.
    if (-e $_[0]) {
	my $sub_name = (caller(0))[3];
	$sub_name =~ s/main:://;
	&parsefile($_[0], "$sub_name $alias" );
	return;
    }

# Otherwise, we need our array of strings mashed into one
    my $command = '';
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
# If it was invoked by direct (instead of run), the $address will 
# be attached in order to send each command to the right host.
# Args: [file to parse] [direct (alias)] [address] 
sub parsefile() {
    chomp(my ($file, $address) = @_);
    tie @file, 'Tie::File', "$file", mode => O_RDONLY;
    my %blacklist = ( sleep => 1 );
    &run_block(1, 0, $address, %blacklist); # Run the main code block, once, from line 0
}

# This is a recursive subroutine.
# This subroutine will read each line in a block of code (each loop is one block)
# and execute the desired instructions. Each nested loop recurses once. 
#
# Should this be a file 'directed' to a host, the address must be supplied. 
# See 'direct' and 'parsefile'. This will look like "direct $alias"
#
# Args: [times to repeat] [line to start parsing] [address] [blacklist]
sub run_block() {
    my ($rep, $line, $address, %run_local) = @_;
    my $i = 1, my $initial = $line, my $final;
    for($i; $i <= $rep; $i++) {
	while ($line < scalar(@file)) {

# If a loop is starting, parse the number of times to repeat and jump in.
	    if ($file[$line] =~ m/{/) { 
		(my $inner_rep = $file[$line]) =~ s/\D//g;
		$line = &run_block($inner_rep, $line+1, $address, %run_local);
	    }
# If we have reached a closing brace, a loop is ending. Reset the 
# program counter and repeat from the beginning, or drop out and go up a level.
	    elsif ($file[$line] =~ m/}/) { 
		$final = $line unless $final;
		$line = $initial;
		last;
	    }
# If not a control statment, this must be a command. Run as such.
	    else { 
		my $command = $file[$line];
		$command = $address . ' ' . $command unless defined $run_local{$command =~ s/[\s\d]+//r};
		&processCommand($command =~ s/^\s+//r); # chomp the beginning
	    }
	    $line++;
	}
    }
    return $final; # Return where inner loop ends for the encompassing loop
}
