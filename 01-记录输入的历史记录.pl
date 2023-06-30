#!/bin/env perl

use strict;
use warnings;

use Term::CLI 0.058002;

my $cli = Term::CLI->new(
    name => 'app',
    prompt => 'app> ',
    cleanup     => sub {
        my ($self) = @_; # 因为是回调函数，所以第一个参数为控制台对象

        # 将历史记录写到文件 `~/.app_history` 中
        # 如果写入失败，会将错误信息写入到 `$self->error` 中
        $self->write_history
           or warn "cannot write history: " . $self->error . "\n";
    },
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

$cli->read_history;  # 从文件 `~/.app_history` 读取历史记

# 跳过空行和注释行
while ( my $input = $cli->readline(skip => qr/^\s*(?:#.*)?$/) )
{
   $cli->execute_line($input);
}