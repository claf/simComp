package Task;

sub new {
  my $class = shift;
  my $self = {};
  $self->{name} = shift;
  $self->{processing_time} = shift;
  $self->{remaining_time} = $self->{processing_time};
  $self->{calls_needed} = {};
  $self->{calls_counters} = {};
  bless($self, $class);
  return $self;
}

# Used to add an outgoing arrow to another comp. :
# call : comp_A->add_call ("B", 10);
sub add_call {
  my $self = shift;
  my $component_name = shift;
  my $count = shift;
  $self->{calls_needed}->{$component_name} = $self->{processing_time} / $count;
  $self->{calls_counters}->{$component_name} = $self->{processing_time} / $count;
}

# This function reduce every remaining time from $time :
sub move_forward {
  my $self = shift;
  my $time = shift;
  
  $self->{remaining_time} -= $time;
  foreach my $call ($self->{calls_counters}) {
    $call -= $time;
  }
}

1;

