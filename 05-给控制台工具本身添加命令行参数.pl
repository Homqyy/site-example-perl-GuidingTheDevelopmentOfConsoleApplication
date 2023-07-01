#!/bin/env perl

use strict;
use warnings;

# 添加Perl搜索路径：当前工程所在目录
use FindBin qw($Bin);
use lib "$Bin";

use Term::CLI 0.058002;

# 导入自定义的命令行参数类
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
  -h, --help      显示帮助信息
  -v, --version   显示版本信息
EOF
    exit 0;
}

if ($conf_version)
{
    print "v1.0.0\n";
    exit 0;
}

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
        Term::CLI::Command->new(
            name        => 'ls',
            description => '查看指定路径下的文件',
            summary     => '查看指定路径下的文件',
            usage       => "ls [OPTIONS] <PATH>\n".
                           "\n".
                           "PATH: 要查看的路径；默认为当前路径，即`.`\n".
                           "\n".
                           "OPTIONS:\n".
                           "  -l   显示文件详细信息",
            arguments   => [
                # 参数类型从 `Term::CLI::Argument::String` 改为 `MyCLI::Argument`
                MyCLI::Argument->new(
                    name        => 'path',
                    min_length  => 1,
                    max_length  => 128,
                    complete    => \&complete_path, # 设置补全方法
                ),
            ],
            options     => [ "l" ],
            callback    => \&cb_ls,
        )
    ],
);

$cli->read_history;  # 从文件 `~/.app_history` 读取历史记

# 跳过空行和注释行
while ( my $input = $cli->readline(skip => qr/^\s*(?:#.*)?$/) )
{
   $cli->execute_line($input);
}

sub cb_ls
{
    my ($self, %args) = @_;

    return (%args) if ($args{status} < 0);

    my @arguments = @{$args{arguments}}; # 提取命令行参数
    my %options   = %{$args{options}};   # 提取命令行选项

    my $path = $arguments[0];

    my @files;

    if (-d $path)
    {
        opendir(my $dh, $path) 
            || return (%args, status => -1,  error => "无法打开目录：$!");

        @files = readdir($dh);
        closedir($dh);
    }
    elsif (-e $path)
    {
        my ($v, $d, $f) = File::Spec->splitpath($path);

        $path = $d ||  '.'; # 如果没有目录，则默认为当前目录

        push @files, $f;
    }
    else
    {
        return (%args, status => -1, error => "无效的路径：$path")
    }

    unless(exists $options{l})
    {
        # 如果没有输入 `-l` 参数，则只打印文件名

        foreach my $file (@files)
        {
            next if ($file eq '.' || $file eq '..');

            print "$file\n";
        }
    }
    else
    {
        # 如果输入了 `-l` 参数，则打印文件详细信息

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

# 函数实现引用了：<https://metacpan.org/dist/Term-CLI/source/lib/Term/CLI/Argument/Filename.pm>
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