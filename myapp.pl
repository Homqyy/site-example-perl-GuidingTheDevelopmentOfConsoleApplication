#!/bin/env perl

use strict;
use warnings;

# Add Perl search path: current project directory
use FindBin qw($Bin);
use lib "$Bin";

use Term::CLI 0.058002;

# Import custom command-line argument class
use MyCLI::Argument;

use File::Glob qw(bsd_glob);

use Getopt::Long;

my $conf_help;
my $conf_version;

GetOptions(
    'help|h'        => \$conf_help,
    'version|v'     => \$conf_version,
);

if ($conf_help)
{
    print <<EOF;
Usage: $0 [OPTIONS]

OPTIONS:
  -h, --help      Display help information
  -v, --version   Display version information
EOF
    exit 0;
}

if ($conf_version)
{
    print "v1.0.0\n";
    exit 0;
}

# Create a `help` command object; can be reused for each command
my $cmd_help = Term::CLI::Command->new(
    name            => 'help',
    summary         => 'View help information',
    usage           => 'help [ COMMAND ]',
    description     => 'View help information',
    callback        => \&cb_help,
);

my $cli = Term::CLI->new(
    name => 'app',
    prompt => 'app> ',
    cleanup     => sub {
        my ($self) = @_;

        # Write command history to the file `~/.app_history`
        $self->write_history
           or warn "cannot write history: " . $self->error . "\n";
    },
    commands => [
        Term::CLI::Command->new(
            name        => 'exit',
            description => 'Exit the console',
            summary     => 'Exit the console',
            usage       => 'exit',
            callback    => sub { exit 0 },
        ),
        $cmd_help, # Reference to the `help` command object
        Term::CLI::Command->new(
            name        => 'ls',
            description => 'List files in the specified path',
            summary     => 'List files in the specified path',
            usage       => "ls [OPTIONS] <PATH>\n".
                           "\n".
                           "PATH: The path to list; default is the current directory, i.e., `.`\n".
                           "\n".
                           "OPTIONS:\n".
                           "  -l   Display detailed file information",
            arguments   => [
                MyCLI::Argument->new(
                    name        => 'path',
                    min_length  => 1,
                    max_length  => 128,
                    complete    => \&complete_path, # Set the completion method
                ),
            ],
            options     => [ "l" ],
            callback    => \&cb_ls,
        ),
        # Add a new command `show` with two subcommands: `memory` and `disk` to display memory and disk information, respectively.
        Term::CLI::Command->new(
            name        => 'show',
            description => 'Display system information',
            summary     => 'Display system information',
            usage       => "show [OPTIONS] <SUBCOMMAND>\n".
                           "\n".
                           "SUBCOMMAND:\n".
                           "  memory   Display memory information\n".
                           "  cpu      Display CPU information",
            callback    => \&cb_show,

            require_sub_command => 0, # Set to 0 to not require a subcommand

            commands => [
                Term::CLI::Command->new(
                    name        => 'memory',
                    description => 'Display memory information',
                    summary     => 'Display memory information',
                    usage       => 'show memory',
                    callback    => \&cb_show_memory,
                ),
                Term::CLI::Command->new(
                    name        => 'disk',
                    description => 'Display disk information',
                    summary     => 'Display disk information',
                    usage       => 'show disk',
                    callback    => \&cb_show_disk,
                ),
            ]
        )
    ],
);

$cli->read_history;  # Read command history from the file `~/.app_history`

# Skip blank lines and comment lines
while ( my $input = $cli->readline(skip => qr/^\s*(?:#.*)?$/) )
{
   $cli->execute_line($input);
}

sub cb_ls
{
    my ($self, %args) = @_;

    return (%args) if ($args{status} < 0);

    my @arguments = @{$args{arguments}}; # Extract command-line arguments
    my %options   = %{$args{options}};   # Extract command-line options

    my $path = $arguments[0];

    my @files;

    if (-d $path)
    {
        opendir(my $dh, $path) 
            || return (%args, status => -1,  error => "Cannot open directory: $!");

        @files = readdir($dh);
        closedir($dh);
    }
    elsif (-e $path)
    {
        my ($v, $d, $f) = File::Spec->splitpath($path);

        $path = $d ||  '.'; # If no directory, default to the current directory

        push @files, $f;
    }
    else
    {
        return (%args, status => -1, error => "Invalid path: $path")
    }

    unless(exists $options{l})
    {
        # If no `-l` parameter is provided, only print file names

        foreach my $file (@files)
        {
            next if ($file eq '.' || $file eq '..');

            print "$file\n";
        }
    }
    else
    {
        # If `-l` parameter is provided, print detailed file information

        foreach my $file (@files)
        {
            next if ($file eq '.' || $file eq '..');

            my $filepath = File::Spec->catfile($path, $file);
            my @stat = stat($filepath);

            printf "%-20s %10d %s\n", 
                $file, $stat[7], scalar localtime($stat[9]);

        }
    }

    return (%args, status => 0);
}

################################ callback subroutine ################################

sub cb_help
{ 
    my ($self, %args) = @_;

    my $line    = $args{command_line};          # Extract command line

    #
    # Overview: Extract the parent command (referred to as the parent command) when we input `help`, a root object `app` is actually added by default, i.e., `app help`. Therefore, the extracted command here is the `app` command object.
    #
    # Details:
    #   By using `command_path`, we can get the path of the command object, such as the path here is: `app help`,
    #   Therefore, `$args{command_path}->[-2]` refers to the second-to-last command object, which is the `app` command object,
    #   Similarly, `$args{command_path}->[-1]` refers to the last command object, which is the `help` command object.
    my $pcmd    = $args{command_path}->[-2];

    my ($help_cmd) = ($line =~ /help (\w+)$/); # Extract the command after `help`

    if (defined $help_cmd)
    {
        #
        # If you want to view the usage instructions of a specific command, print the detailed description and usage of that command, e.g., help help
        # Similar to:
        #   app> help help
        #   ===== Detailed Description =====
        #   View help information
        #
        #   ===== Usage =====
        #   help [ command ]
        #

        my $cmd     = $pcmd->find_command($help_cmd); # Find the command object

        $cmd || return (%args, status => -1, error => $pcmd->error); # If the command does not exist, return an error

        print "===== Detailed Description =====\n";
        print $cmd->description . "\n\n";
        print "===== Usage =====\n";
        print $cmd->usage . "\n\n";
    }
    else
    {
        #
        # If the `help` command is entered without specifying a command name, print an overview of all child commands belonging to the parent command
        # Similar to:
        #   app> help
        #   exit            Exit the console
        #   help            View help information

        foreach my $name ($pcmd->command_names)
        {
            my $cmd = $pcmd->find_command($name);

            my $summary = $cmd->summary // "unknwon";

            printf "%-15s\%s\n", $name, $summary;
        }
    }

    return (%args, status => 0);
}

sub cb_show_memory
{
    my ($self, %args) = @_;

    return (%args) if ($args{status} < 0);

    my $memory = `free -h`;

    print $memory;

    return (%args, status => 0);
}

sub cb_show_disk
{
    my ($self, %args) = @_;

    return (%args) if ($args{status} < 0);

    my $disk = `df -h`;

    print $disk;

    return (%args, status => 0);
}

sub cb_show
{
    my ($self, %args) = @_;

    return (%args) if ($args{status} < 0);

    # Ignore cases where `show` command is not directly executed
    unless ($args{command_line} =~ /^show\s*$/)
    {
        return %args;
    }

    # Enter the show node
    while (my $input = $self->readline(prompt => "show> ", skip => qr/^\s*(?:#.*)?$/))
    {
        my (%args) = $self->execute_line($input);

        if ($args{status} != 0)
        {
            print "ERROR: " . $args{error} . "\n";
        }
    }

    return %args;
}

################################ complete subroutine ################################

# The function implementation references: <https://metacpan.org/dist/Term-CLI/source/lib/Term/CLI/Argument/Filename.pm>
sub complete_path
{
    my ($self, $text, $state) = @_;

    my @list = bsd_glob("$text*");

    return if @list == 0;

    if (@list == 1)
    {
        if (-d $list[0])
        {
            # Dumb trick to get readline to expand a directory
            # with a trailing "/", but *not* add a space.
            # Simulates the way GNU readline does it.
            return ("$list[0]/", "$list[0]//");
        }

        return @list;
    }

    # Add filetype suffixes if there is more than one possible completion.
    foreach (@list) {
        lstat;
        if ( -l _ )  { $_ .= q{@}; next } # symbolic link
        if ( -d _ )  { $_ .= q{/}; next } # directory
        if ( -c _ )  { $_ .= q{%}; next } # character special
        if ( -b _ )  { $_ .= q{#}; next } # block special
        if ( -S _ )  { $_ .= q{=}; next } # socket
        if ( -p _ )  { $_ .= q{=}; next } # fifo
        if ( -x _ )  { $_ .= q{*}; next } # executable
    }
    return @list;
}
