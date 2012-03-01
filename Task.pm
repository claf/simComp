package Task;

use strict;
use warnings;
use Math::Round;

sub new {
  my $class = shift;
  my $self = {};
  $self->{type} = shift;
  $self->{remaining_time} = shift;
  $self->{component} = shift;
  $self->{deadline} = shift;
  $self->{next_token} = {};
  $self->{processor} = 0;
  bless($self, $class);
  return $self;
}

sub delete {
  my $self = shift;
  my $comp = Component::get_component_by_name($self->{type});
  
  $comp->delete_task ();
}

sub is_finished {
  my $self = shift;
  return !($self->{remaining_time});
}

sub scheduled {
  my $self = shift;
  my $proc = shift;
  $self->{processor} = $proc;
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

  if ($self->{remaining_time} != -1) {
    #print "remaining of $self->{type} : $self->{remaining_time} - $time = ";
    $self->{remaining_time} = nearest (0.0001, $self->{remaining_time} - $time);
    #print "$self->{remaining_time}\n";
    if ($self->{remaining_time} < 0) {
      exit 1;
    }
  }

  foreach my $call (keys (%{$self->{next_token}})) {
    #print "nextoken to $call : $self->{next_token}->{$call} - $time = ";
    $self->{next_token}->{$call} = nearest (0.0001, $self->{next_token}->{$call} - $time);
    #print "$self->{next_token}->{$call}\n";
    if ($self->{next_token}->{$call} < 0) {
      exit 1;
    }
  }
}

# Return the minimum time to wait for next event in this task :
sub min_time {
  my $self = shift;
  my $min = $self->{remaining_time};

  foreach my $comp (keys (%{$self->{next_token}})) {
    if (($min > $self->{next_token}{$comp}) || ($min < 0)) {
      $min = $self->{next_token}{$comp};
    }
  }
  return $min;
}

# Add coins to components if needed :
sub add_coins {
  my $self = shift;
  my $global_time = shift;
  my $next_component;

  for my $comp_name (keys (%{$self->{next_token}})) {
    if ($self->{next_token}{$comp_name} == 0) {
      $next_component = Component::get_component_by_name($comp_name);
      $next_component->add_coin($self->{type});
      #print "Adding one coin from $self->{type} to $next_component->{name} counter is now $next_component->{token_counter} at $global_time\n";
      $self->{next_token}{$comp_name} = $self->{component}->token($comp_name);
    }
  }
}

1;

