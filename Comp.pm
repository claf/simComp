package Component;

use strict;
use warnings;

our %components;

sub new {
  my $class = shift;
  my $self = {};
  $self->{name} = shift;
  $self->{processing_time} = shift;
  $self->{token_needed} = shift;
  $self->{concurrency} = shift;
  $self->{priority} = shift;
  $self->{token_counter} = 0;
  $self->{nb_tasks} = 0;
  $self->{calls} = {};
  bless($self, $class);
  $components{$self->{name}} = $self;
  return $self;
}

sub add_task {
  my $self = shift;
  my $work = shift;
  
  if ($self->{token_needed} == 0) {
    $self->create_task ($work);
  } else {
    $self->{token_counter} += $self->{token_needed};
  }
}

sub delete_task {
  my $self = shift;

  if ($self->{concurrency} != -1) {
    $self->{nb_tasks}--;
    if ($self->{nb_tasks} < 0) {
      exit 1;
    }
  }
}

sub add_coin {
  my $self = shift;
  $self->{token_counter}++;
}

sub get_component_by_name {
  my $name = shift;
  return $components{$name};
}

# Used to add an outgoing arrow to another comp. :
# call : comp_A->add_call ("B", 10);
# if A is an endless component, then $count is the time between two calls to
# B.
sub add_call {
  my $self = shift;
  my $component_name = shift;
  my $count = shift;

  if ($self->{processing_time} == -1) {
    $self->{calls}->{$component_name} = $count;
  } else {
    $self->{calls}->{$component_name} = $self->{processing_time} / $count;
  }
}

# Used to create a new task :
sub create_task {
  my $self = shift;
  my $work = shift;
  my $deadline = -1;

  my $task = new Task ($self->{name}, $self->{processing_time}, $self, $deadline);

  foreach my $comp (keys (%{$self->{calls}})) {
    $task->init_token ($comp, $self->{calls}->{$comp});
  }

  if ($self->{concurrency} > 0) {
    if ($self->{nb_tasks} < $self->{concurrency}) {
      $self->{nb_tasks}++;
    } else {
      exit 1;
    }
  }

  if ($work->{priority} < $self->{priority}) {
    print "Component priority is too high, max priority is $work->{priority}\n";
    $work->insert_task ($task, $work->{priority});
  } else {
    $work->insert_task ($task, $self->{priority});
  }
}

# Return default time before next event for comp in argument :
sub token {
  my $self = shift;
  my $comp = shift;
  return $self->{calls}->{$comp};
}

# Check counter to see if it needs to create a task :
sub check_counter {
  my $self = shift;
  my $work = shift;

  if ($self->{token_needed} == 0) {
    return;
  }

  if ($self->{concurrency} == -1) {
    while ($self->{token_counter} >= $self->{token_needed}) {
      $self->create_task ($work);
      $self->{token_counter} -= $self->{token_needed};
    }
  } else {
    while (($self->{token_counter} >= $self->{token_needed}) && ($self->{nb_tasks} < $self->{concurrency})) {
      if (($self->{nb_tasks} < $self->{concurrency}) || ($self->{concurrency} == -1)) {
        $self->create_task ($work);
        $self->{token_counter} -= $self->{token_needed};
      }
    }
  }
}

1;

