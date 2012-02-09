package Task;

sub new {
  my $class = shift;
  my $self = {};
  $self->{type} = shift;
  $self->{remaining_time} = shift;
  $self->{deadline} = shift;
  $self->{next_token} = {};
  bless($self, $class);
  return $self;
}

# Used to add an outgoing arrow to another comp. :
sub init_token {
  my $self = shift;
  my $component_name = shift;
  my $time = shift;

  $self->{next_token}->{$component_name} = $time;
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

# Return the minimum time to wait for next event in this task :
sub min_time {
    my $self = shift;
    my $min = $self->{remaining_time};

    foreach my $comp (keys (%{$self->{next_token}})) {
	if ($min > $self->{next_token}{$comp}) {
	    $min = $self->{next_token}{$comp};
	}
    }
    return $min;
}

# Add coins to components if needed :
sub add_coins {
    my $self = shift;
    
    foreach my $comp_name (keys (%{$self->{next_token}})) {
	if ($self->{next_token}{$comp_name} == 0) {
	    $Comp{$comp_name}->add_coin ();
	    $self->{next_token}{$comp_name} = $Comp{$self->{type}}->token ($comp_name);
	}
    }

}

1;

