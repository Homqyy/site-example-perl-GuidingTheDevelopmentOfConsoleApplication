#!/bin/env perl

use strict;
use warnings;

use Term::CLI 0.058002;

# 创建一个 `help` 命令对象；后面可以被复用到每个命令中
my $cmd_help = Term::CLI::Command->new(
    name            => 'help',
    summary         => '查看帮助信息',
    usage           => 'help [ command ]',
    description     => '查看帮助信息',
    callback        => \&cb_help,
);

my $cli = Term::CLI->new(
    name => 'app',
    prompt => 'app> ',
    cleanup     => sub {
        my ($self) = @_;

        # 将历史记录写到文件 `~/.app_history` 中
        $self->write_history
           or warn "cannot write history: " . $self->error . "\n";
    },
    commands => [
        Term::CLI::Command->new(
            name        => 'exit',
            description => '退出控制台',
            summary     => '退出控制台',
            usage       => 'exit',
            callback => sub { exit 0 },
        ),
        
        $cmd_help, # 引用 `help` 命令对象
    ],
);

$cli->read_history;  # 从文件 `~/.app_history` 读取历史记

# 跳过空行和注释行
while ( my $input = $cli->readline(skip => qr/^\s*(?:#.*)?$/) )
{
   $cli->execute_line($input);
}

sub cb_help
{ 
    my ($self, %args) = @_;

    my $line    = $args{command_line};          # 提取命令行

    #
    # 概述：提取前一个命令对象（后续称为父命令）：当我们输入`help`时，其实会默认加入一个根对象`app`，即`app help`。因此这里提取的是`app`命令对象。
    #
    # 详述：
    #   通过 `command_path` 可以获取到命令对象的路径，比如这里的路径为：`app help`，
    #   因此，`$args{command_path}->[-2]` 意思是倒数第二个命令对象，即 `app` 命令对象，
    #   同理，`$args{command_path}->[-1]` 意思是倒数第一个命令对象，即 `help` 命令对象。
    my $pcmd    = $args{command_path}->[-2];

    my ($help_cmd) = ($line =~ /help (\w+)$/); # 提取 `help` 之后的命令

    if (defined $help_cmd)
    {
        #
        # 如果要查看指定命令的使用说明，则打印该命令的详细说明和使用方法，比如：help help
        # 效果类似于：
        #   app> help help
        #   ===== 详细说明 =====
        #   查看帮助信息
        #
        #   ===== 使用方法 =====
        #   help [ command ]
        #

        my $cmd     = $pcmd->find_command($help_cmd); # 查找命令对象

        $cmd || return (%args, status => -1, error => $pcmd->error); # 如果命令不存在，则返回错误

        print "===== 详细说明 =====\n";
        print $cmd->description . "\n\n";
        print "===== 使用方法 =====\n";
        print $cmd->usage . "\n\n";
    }
    else
    {
        #
        # 如果输入了 `help` 命令，但是没有输入命令名称，则打印所有属于父命令的子命令的概述
        # 效果类似于：
        #   app> help
        #   exit            退出控制台
        #   help            查看帮助信息

        foreach my $name ($pcmd->command_names)
        {
            my $cmd = $pcmd->find_command($name);

            my $summary = $cmd->summary // "unknwon";

            printf "%-15s\%s\n", $name, $summary;
        }
    }

    return (%args, status => 0);
}