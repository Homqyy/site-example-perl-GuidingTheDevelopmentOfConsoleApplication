package MyCLI::Argument;

use strict;
use warnings;

use Term::CLI::Argument::String;

# 为了方便，我们继承了 Term::CLI::Argument::String
our @ISA = qw(Term::CLI::Argument::String);

# 重写 `new` 方法
sub new
{
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);

    $self->{complete} = $args{complete} if exists $args{complete};

    bless $self, $class;

    return $self;
}

# 重写 `complete` 方法
sub complete
{
    my ($self, $text, $state) = @_;

    # 如果用户没有指定 `complete` 方法，我们就调用父类的 `complete` 方法
    return $self->SUPER::complete($text, $state) unless $self->{complete};

    # 如果用户指定了 `complete` 方法，我们就调用它
    return $self->{complete}->($self, $text, $state);
}

1;