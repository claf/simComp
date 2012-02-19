package Work;

use strict;
use warnings;

sub new {
  my $class = shift;
  my $self = {};
  $self->{priority} = shift;
  $self->{fifo} = shift;
  $self->{queue} = [];
  bless($self, $class);
  return $self;
}

# add deadline management in the queue (struct {task,deadline}) :
sub insert_task {
  my $self = shift;
  my $task = shift;
  my $prio = shift;

  push (@{$self->{queue}[$prio]}, $task);
}

sub get_task {
  my $self = shift; 
  my $prio = $self->{priority};

  while ($prio > 0) {
    if (@{$self->{queue}[$prio]}) {
      if ($self->{fifo}) {
        return shift (@{$self->{queue}[$prio]}); 
      } else {
        return pop (@{$self->{queue}[$prio]}); 
      }
    }
    $prio -= 1;
  }
}

sub is_empty {
  my $self = shift;
  my $prio = $self->{priority};

  while ($prio > 0) {
    if (@{$self->{queue}[$prio]}) {
      return 0;
    }
    $prio -= 1;
  }

  return 1;
}

1;
