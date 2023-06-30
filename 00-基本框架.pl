#!/bin/env perl

use strict;
use warnings;

use Term::CLI;

my $cli = Term::CLI->new(
    name => 'app',
    prompt => 'app> ',
    commands => [
        Term::CLI::Command->new(
            name => 'exit',
            callback => sub { exit 0 },
        ),
        Term::CLI::Command->new(
            name => 'help',
            callback => sub { 
                my ($self, %args) = @_;

                print "help\n";

                return (%args, status => 0); 
            },
        ),
    ],
);

# 跳过空行和注释行
while ( my $input = $cli->readline(skip => qr/^\s*(?:#.*)?$/) )
{
   $cli->execute_line($input);
}