package Component;

sub new {
  my $class = shift;
  my $self = {};
  $self->{name} = shift;
  $self->{processing_time} = shift;
  $self->{token_needed} = shift;
  $self->{token_counter} = 0;
  $self->{calls} = {};
  bless($self, $class);
  return $self;
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
  my $deadline = -1;

  my $task = new Task ($self, $self->{processing_time}, $deadline);

  foreach my $comp (keys (%{$self->{calls}})) {
      $task->init_token ($comp, $self->{calls}->{$comp});
  }

  push (@Work, $task);
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

    while ($self->{token_counter} >= $self->{token_needed}) {
	$self->create_task ();
	$self->{token_counter} -= $self->{token_needed};
    }
}

1;

