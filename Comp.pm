package Component;

use strict;
use warnings;
use Math::Round qw(:all);

our %components;

sub new {
  my $class = shift;
  my $self = {};
  $self->{name} = shift;
  $self->{processing_time} = shift;
  $self->{concurrency} = shift;
  $self->{priority} = shift;
  $self->{token_needed} = {};
  $self->{token_counter} = {};
  $self->{tasks_to_create} = {};
  $self->{nb_tasks} = 0;
  $self->{calls} = {};
  bless($self, $class);
  $components{$self->{name}} = $self;
  return $self;
}

sub add_task {
  my $self = shift;
  my $work = shift;
  
  # TODO : why dont add tokens?
  $self->create_task ($work);

#  if ($self->{token_needed} == 0) {
#    $self->create_task ($work);
#  } else {
#    $self->{token_counter} += $self->{token_needed};
#  }
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
  my $source = shift;
  $self->{token_counter}->{$source}++;
}

sub get_component_by_name {
  my $name = shift;
  return $components{$name};
}

# Used to add an incoming arrow from another comp. :
# call : comp_A->add_inc ("B", 10);
# means comp_A needs at least 10 calls from B to launch!
sub add_inc {
  my $self = shift;
  my $component_name = shift;
  my $count = shift;

  $self->{token_needed}->{$component_name} = $count;
  $self->{token_counter}->{$component_name} = 0;
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
    $self->{tasks_to_create}->{$component_name} = -1;
  } else {
    # rounding to 0.01, storing how many tasks to create :
    $self->{calls}->{$component_name} = nearest_floor (0.01, ($self->{processing_time} / $count));
    print "Rounding calls for $component_name from $self->{name} to $self->{calls}->{$component_name}, count is $count\n";
    $self->{tasks_to_create}->{$component_name} = $count;
  }
}

# Used to create a new task :
sub create_task {
  my $self = shift;
  my $work = shift;
  my $deadline = -1;

  if ($self->{concurrency} > 0) {
    if ($self->{nb_tasks} < $self->{concurrency}) {
      $self->{nb_tasks}++;
    } else {
      exit;
    }
  }

  # Create the task object :
  my $task = new Task ($self->{name}, $self->{processing_time}, $self, $deadline);

  foreach my $comp (keys (%{$self->{calls}})) {
    $task->init_token ($comp, $self->{calls}->{$comp}, $self->{tasks_to_create}->{$comp});
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

  # If the component doesn't have sources then exit :
  if (!keys (%{$self->{token_needed}})) {
    return;
  }

  while (1) {
    # If I can't create another task of this component type then exit :
    if ($self->{nb_tasks} == $self->{concurrency}) {
      return;
    }

    for my $key (keys(%{$self->{token_needed}})) {
      if ($self->{token_needed}->{$key} > $self->{token_counter}->{$key}) {
        return;
      }
    }

    for my $key (keys(%{$self->{token_needed}})) {
      $self->{token_counter}->{$key} -= $self->{token_needed}->{$key};
    }
    $self->create_task ($work);
  }

}

1;

