package Task;

use strict;
use warnings;


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
    $self->{remaining_time} -= $time;
  }

  foreach my $call (keys (%{$self->{next_token}})) {
    $self->{next_token}->{$call} -= $time;
  }
  #$self->add_coins ();
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
#    # in order to get rid of precision problem?
#    if (($self->{remaining_time} == 0) && ($self->{next_token}{$comp_name} != $self->{component}->token($comp_name))) {
#      print "ok j'en rajoute un dans $comp_name parce que c est presque fini\n";
#      $next_component = Component::get_component_by_name($comp_name);
#      $next_component->add_coin();
#    }

    if ($self->{next_token}{$comp_name} == 0) {
      $next_component = Component::get_component_by_name($comp_name);
      $next_component->add_coin();
      print "Adding one coin from $self->{type} to $next_component->{name} counter is now $next_component->{token_counter} at $global_time\n";
      $self->{next_token}{$comp_name} = $self->{component}->token($comp_name);
    }
  }
}

1;

