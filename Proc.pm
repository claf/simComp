package Processor;

sub new {
  my $class = shift;
  my $self = {};
  $self->{name} = shift;
  $self->{frequency} = shift;
  $self->{executing} = ();;
  bless($self, $class);
  return $self;
}

sub execute {
  my $self = shift;
  my $task = shift;

  push ($self->{executing}, $task);
}

# Return >1 or 0 regarding if processor is working :
sub is_working {
  my $self = shift;

  # return the number of tasks in executing list
  return scalar ($self->{executing});
}

# This function reduce every remaining time from $time :
sub move_forward {
  my $self = shift;
  my $time = shift;
  
  foreach my $task ($self->{executing}) {
      $task->move_forward ($time);
  }
}

# Remove ended tasks :
sub delete_task {
    my $self = shift;
    
    if (!$self->is_working ()) {
      return 1;
    }

    if ($self->{executing}->{remaining_time} == 0) {
	print TRACEHANDLER "12 $global_time \"SP\" \"P$worker\"\n";
	shift @self->{executing};
    }
}

sub currently_executing {
    my $self = shift;
    return $self->{executing}[0];
}

1;
