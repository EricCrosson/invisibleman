# Invisible man

This is a unit-testing framework, designed to interact with any number
of remote hosts by sending them commands at specified intervals. This
framework is intended to be transparent to the hosts, acting as an
"invisible ... man."

## Documentation

Extensive documentation is included inside the source files, which I
may one day transfer here should I find the time. Also included are
sample files to feed into the invisible man.

## Getting started

Open up the file `shell.pl` to begin your journey browsing code, or
read on to get a better feel for the definition of this scripting
tool.

---

# A Guide to Writing Modules for the Automation Scripting Tool

The Automation Scripting Tools is a command interpreter, written in
Perl, that allows for the control of any number of hosts over ssh in a
familiar programming environment. In order to connect to a host, you
have to set a few configuration options. These can be hard coded into
the script (see the %ssh hash) or chosen dynamically at run-time.

## 'The Problem' This Program Solves

This program allows for a very concise and flexible way to control and
monitor an arbitrary number of remote hosts simultaneously. In
particular, the remote hosts in mind were telephones running Linux,
with SSH authentication certificates. Most of this document will
provide examples regarding phones and the types of behaviors that a
typical phone might encounter. Please note that the applications of
this tool do not stop there. This tool was originally designed to
allow for a quick and painless interface for developers to test their
code on telephones before checking anything in to the main repo for
testing by QA. It is believed that easier unit testing would promote
unit testing, and better testing would improve the quality of code
included in each checkin.

## Dependencies

This program is entirely implemented in Perl, and as such uses a Perl
package for SSH. If the utilized packages aren't installed, install
them with

```bash
curl -L http://cpanmin.us | perl - --sudo Net::SSH2
```

## Connecting to Remote Hosts
Now that we may run the shell without probolems, fire it up in most
shells with `./shell.pl`. We are immediately presented with a
prompt. Let's get started connecting to some remote hosts, as this
section's title hinted.

In order to connect as admin with a known set of keys, Henry would write

```lisp
config admin /home/henry/.ssh/hq_rsa.pub /home/henry/ssh/hq_rsa
```

When logging in to a host, the `connect` command is used.

```lisp
connect 10.162.2.101
connect 10.162.2.108 henry
connect 10.162.2.137 recipient
```

For convenience, a host can be referenced by its alias. As of the latest
release, an alias may only be administered at the time of connection.

## Issuing Commands to Hosts

Now that we are connected to some hosts, we can issuing commands. The
`direct` command is used to forward instructions to connected
hosts. It may be useful to have a good toolbox of useful commands
prepared on the phone (host) side, as well as the control side. Some
short modules could easily be included in the CLI, allowing for a wide
range of functions. The `direct` command will invoke a function on the
phone, and return when the function returns. Output is forwareded
immediately to the scripting tool. An example script might look as
follows:

```lisp
; Any line with a semicolon is a comment.
; And according to my directory, Henry's extension is 555.
; The keycode for 5 is 35

direct marta push 35 ; number 5
direct marta push 35
direct marta push 35
direct marta push 17660 ; dial
direct recipient answer_incoming
```

where `push` is an imaginary command in the cli that tells the phone
buttons have been pushed. Buttons are referred to by their keycodes
`x` through the `forgeDTMF` command:
`forgeDTMF x 1`
`forgeDTMF x 0`

and `answer_incoming` is a CLI command that waits until recognizing an
incoming call, answers it, (perhaps delaying a small amount for audio
cut-through and RTP establishment,) and returns.

When the above snippet completes, the two phones will be engaged in a
call.

## I Remember Something About Conciseness

This syntax is rather bulky, and it's nice to save keystrokes and time. Instead
of utilizing rectangular inserts cleverly, one can write a block of code as a
subroutine. In a separate file, write a block of code you would like to direct
to a host. Let's call this file `dial555.auto`, and make it behave identically
to the above script:

```lisp
push 35 ; number 5
push 35
push 35
push 17660 ; dial
```
Now our main code has been shortened to:

```lisp
config admin /home/henry/.ssh/hq_rsa.pub /home/henry/ssh/hq_rsa
connect 10.162.2.137 marta
connect 10.162.2.108 recipient ; say his ext. is 555
direct marta dial555.auto
direct recipient answer_incoming
```

### Aliases

In addition to subroutines, this scripting tool sticks to aliases
almost as religiously as GDB. Every command save one may be shortened
to its respective first letter. The one command without an alias is
`disconnect`, which would overlap with the much mightier `direct`, and
I take as no great loss because it shouldn't be called in a hurry
anyway.

## Approaching a Programming Language

We have seen how to implement
- local variables (aliased instances of remote hosts),
- control hosts with directives, and
- group directives into meaningful chunks.

We have introduced a documentation system. I hope I'm not the only one
starting to notice the resemblance.

Finally, no language would be useful without loops. Loops in this
language take one argument: the number of times to repeat the
loop. For one wanting to repeat a loop `n` times, the syntax is:

```lisp
n {
; commands
; more commands
}
```

taking care to place the bounds of the loop on lines by
themselves. Nested loops are supported, as well as loops within
subroutines. There is no error handling for 'hidden' brackets
[eg: `direct localhost final command } ; Done with everything!`
will cause ridiculous parsing behavior].

## API

processCommand()

> This subroutine directs input to where it needs to go. Files are parsed,
> methods are invoked, or an error is thrown.

do_exit()

> Wrapper for the exit function. This allows for error codes

prompt()

> This subroutine prints the configured string to ask for input and returns a command

search()

> This subroutine is used only for debugging. If an alias is specified,
> print information about that alias. Else, list the entire directory.
> Args: [list of names]

config()

> This subroutine allows for changing of ssh options during runtime.
> The ssh connection will use these settings for authentication.
> Args: [username] [path to public key] [path to private key]

help_message()

> This subroutine will print a list of commands recognized by the script.
> If a specific command is included in the query, the method searches the
> helptext hash for a command-specific string to display.
> Args: [command]

connect()

> This subroutine will establish a connection to the specified host, storing
> the resulting object in a hash. In this way, we can name our connections
> in a human-readable manner, and send them commands and gather output with ease.
> Args: [host] [alias]

direct()

> This subroutine forwards a directive to the specified host as a string.
> If one wishes to send more than just one string, specify a file with
> a list of commands (minus the 'direct [alias]'. This file will be parsed
> and each line will be sent to the target computer.
> Args: [alias] [command|file]

disconnect()

> This subroutine disconnects from a specified host and frees associated memory.
> Args: [list of aliases to disconnect]

parsefile()

> This subroutine begins the recursive parsing of the supplied file.
> If it was invoked by direct (instead of run), the $address will
> be attached in order to send each command to the right host.
> Args: [file to parse] [address]

run_block()

> Note: This is a recursive subroutine.
> This subroutine will read each line in a block of code (each loop is one block)
> and execute the desired instructions. Each nested loop recurses once.
>
> Should this be a file 'directed' to a host, the address must be supplied.
> See 'direct' and 'parsefile'. This will look like "direct $alias"
>
> Args: [times to repeat] [line to start parsing] [address] [file to parse] [blacklist]

## Syntax Highlighting

Though modest, there is currently a minor mode to help edit automation
scripts. Evaluating the following line in Emacs will enable
highlighting in all files ending in `.auto`

```lisp
(load-library "resources/invisible-mode")
```
