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
  $self->{token_counter} = 0;
  $self->{calls} = {};
  bless($self, $class);
  $components{$self->{name}} = $self;
  return $self;
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
sub add_call {
  my $self = shift;
  my $component_name = shift;
  my $count = shift;

  $self->{calls}->{$component_name} = $self->{processing_time} / $count;
}

# Used to create a new task :
sub create_task {
  my $self = shift;
  my $refWork = shift;
  my $deadline = -1;

  my $task = new Task ($self->{name}, $self->{processing_time}, $self, $deadline);

  foreach my $comp (keys (%{$self->{calls}})) {
    $task->init_token ($comp, $self->{calls}->{$comp});
  }

  push (@{$refWork}, $task);
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
  my $refWork = shift;

  if ($self->{token_needed} == 0) {
    return;
  }

  while ($self->{token_counter} >= $self->{token_needed}) {
    $self->create_task ($refWork);
    $self->{token_counter} -= $self->{token_needed};
  }
}

1;

