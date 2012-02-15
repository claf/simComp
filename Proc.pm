package Processor;

use strict;
use warnings;

# TODO : take into account proc freq when moving forward.
# min_time need to be a proc function now so that task->min_time will be
# multiplied by proc freq and then return! (be carefull)
sub new {
  my $class = shift;
  my $self = {};
  $self->{name} = shift;
  $self->{frequency} = shift;
  $self->{executing} = [];
  bless($self, $class);
  return $self;
}

sub execute {
  my $self = shift;
  my $task = shift;

  push (@{$self->{executing}}, $task);
  $task->scheduled($self);
}

# Return >1 or 0 regarding if processor is working :
sub is_working {
  my $self = shift;

  # return the number of tasks in executing list
  return scalar @{$self->{executing}};
}

# This function reduce every remaining time from $time :
sub move_forward {
  my $self = shift;
  my $time = shift;

  for my $task (@{$self->{executing}}) {
    $task->move_forward ($time);
  }
}

# Remove ended tasks :
sub delete_task {
  my $self = shift;

  if ($self->{executing}->[0]->{remaining_time} == 0) {
    # TODO : decrement le compteur de composant nb_tasks :
    $self->{executing}->[0]->delete ();
    shift @{$self->{executing}};
  } else {
    exit 1;
  }
}

sub currently_executing {
  my $self = shift;
  return $self->{executing}->[0];
}

1;
