#!/usr/bin/perl

use strict;
use Task;

my $iter = shift;
my $proc = shift;
my $file = shift;
my $global_time = 0;

my %Proc = ();

# Actual coin counter :
my %Incoming_counters = ();
my @Work = ();

#print "Running $iter iterations with $proc proccessing units";

#my %Time = ("A", 2, "B", 5, "C", 1);
my %Time = ();
#my %Calls = (
#  "A"=> {"B" => 1,},
#  "B"=> {"C" => 10,},
#  "C"=> {"A"=> 1,},
#            ):
my %Calls = ();

my %Incoming_needed = ();
#$Incoming_needed{"A"} = 10;
#$Incoming_needed{"B"} = 1;
#$Incoming_needed{"C"} = 1;

# rempli la structure incoming_needed :
# dans le fichier je dois avoir le point de depart (premiere tache à inserer
# dans @Work pour commencer l'execution :
parse_file ($file);

foreach my $comp (keys (%Incoming_needed)) {
  $Incoming_counters{$comp} = 0;
}

# Processing unit list initialisation :
for (my $key = 1; $key <= $proc; $key++) {
  $Proc{$key} = 0;
}

print "Start The Loop\n";

while ($iter)
{
  # suppress ended tasks :
  #print "delete ended tasks\n";
  delete_tasks ();

  # schedule available tasks onto free ressources :
  #print "schedule available tasks onto free ressources :\n";
  schedule_tasks ();

  # increment global counters :
  #print "increment global counters\n";
  increment_counters ();

  # find the minimal amount of time to next event :
  my $min_time = min_time ();
  
  #if ($min_time != 0) {
  #print "Next step will skip $min_time time unit\n";

    # reduce components remaining time :
    print "move forward $min_time at $global_time\n";

    move_forward ($min_time);
    $global_time += $min_time;
    #}

  # create new tasks in @Work :
  #print "create new tasks and insert in Work\n";
  increment_counters ();
  create_tasks();
  delete_tasks ();

  # next step :
  $iter--;
  #print "Current time is $global_time\n";
}

print "End The Loop\n";



#######################
# Utility functions : #
#######################

# Parse application file and fill structures :
sub parse_file {
  my $file = shift;

  open(FILEHANDLER, $file) or die $!;

  my $line = <FILEHANDLER>;
  chomp ($line);

  # First line contain each component, its incoming_needed and its execution
  # time :
  my @args = split (/,/, $line);
  while (@args) {
    my $comp = shift (@args);
    my $inc  = shift (@args);
    my $time = shift (@args);

    $Time{$comp} = $time;
    $Incoming_needed{$comp} = $inc;
  }

  # space :
  $line = <FILEHANDLER>;
  if ($line !~ /^-\n/ ) {
    exit 0;
  }

  # Next lines contain each component arrow to a son and its inserted coin in
  # one execution :
  $line = <FILEHANDLER>;
  while ($line !~ /^-\n/) {
    chomp($line);
    @args = split (/,/, $line);
    my $comp = shift (@args);

    while (@args) {
      my $dest = shift (@args);
      my $coin = shift (@args);

      $Calls{$comp}{$dest} = $coin;
    }
    $line = <FILEHANDLER>;
  }

  # space :
  $line = <FILEHANDLER>;
  chomp($line);
  
  # Last line contain the first task to schedule :
  @args = split (/,/, $line);
  foreach my $task (@args) {
    insert_task ($task);
  }
}

# check the global counter to create new tasks :
sub create_tasks {
  foreach my $key (keys (%Incoming_counters)) {
    while (($Incoming_counters{$key} >= $Incoming_needed{$key}) &&
      ($Incoming_needed{$key} != 0)) {
      # Insert a task into the workqueue :
      insert_task ($key);

      # Update the new counter value :
      $Incoming_counters{$key} -= $Incoming_needed{$key};
    }
  }
}

# Create an object of type argument :
sub insert_task {
  my $type = shift;

  my $comp = new Task ($type, $Time{$type});
  foreach my $call (keys (%{$Calls{$type}})) {
    $comp->add_call ($call, $Calls{$type}{$call});
  }
  push (@Work, $comp);
  #print "Created $type task pushed in workqueue at $global_time\n";
}

# increment global counters :
sub increment_counters {
  my @comps = currently_executed ();
  foreach my $comp (@comps) {
    foreach my $call (keys (%{$comp->{calls_needed}})) {
      #print "Keys : $call\n";
      if ($comp->{calls_counters}->{$call} == 0) {
        print "Added on coin in the $call Comp\n";
        $Incoming_counters{$call}++;
        $comp->{calls_counters}->{$call} = $comp->{calls_needed}->{$call};
      }
    }
  }
}

# return the list of currently executed tasks :
sub currently_executed {
  my @result = ();
  my @workers = currently_working ();
  foreach my $worker (@workers) {
    push (@result, $Proc{$worker}); 
  }
  return @result;
}

# delete finished tasks from %Proc :
sub delete_tasks {
  my @workers = currently_working ();
  foreach my $worker (@workers) {
    if ($Proc{$worker}->{remaining_time} == 0) {
      print "Ended task $Proc{$worker}->{name} at $global_time on $worker\n"; 
      $Proc{$worker} = 0;
    }
  }
}

# update every remaining_time and return the list of (newly?) free ressource
# (what about new tasks creation?)
sub move_forward {
  my $time = shift;

  my @currently_working = currently_working ();
  foreach my $key (@currently_working) {
    $Proc{$key}->{remaining_time} -= $time;
    foreach my $call (keys (%{$Proc{$key}->{calls_counters}})) {
      $Proc{$key}->{calls_counters}->{$call} -= $time;
    }
  }
}

# return the minimum time before next event :
sub min_time {
  my @comps = currently_executed ();
  my $min = 0;

  foreach my $comp (@comps) {
    foreach my $call (keys (%{$comp->{calls_counters}})) {
      if (($min == 0) || ($comp->{calls_counters}->{$call} < $min)) {
        $min = $comp->{calls_counters}->{$call};
      }
    }
    if (($min == 0) || ($comp->{remaining_time} < $min)) {
      $min = $comp->{remaining_time};
    }
  }


  return $min;
}

# return the list of currently working ressources :
sub currently_working {
  my @result = ();
  for (my $key = 1; $key <= $proc; $key++) {
    if ($Proc{$key} != 0) {
      #print "$key is currently working\n";
      push (@result, $key);
    }
  }
  return @result;
}

# schedule tasks onto available ressources :
sub schedule_tasks {
  #print "Start Schedule\n";
  if (@Work) {
    # print "Work to schedule\n";
     
    # get list of free ressources :
    my @freeR = free_ressources ();
    foreach my $ressource (@freeR) {
      # print "Ressource $ressource avaliable\n";

      # to change the policy, use 'schedulable_tasks' function :
      if (@Work) {
        $Proc{$ressource} = shift @Work;
        print "Scheduled task $Proc{$ressource}->{name} on $ressource at time $global_time\n";
      }
    }
  } else {
    # print "No Work to do!\n";
  }
}

# return the list of schedulable tasks on ONE ressource :
sub schedulable_tasks {
  return @Work;
}

# return the list of available ressources :
sub free_ressources {
  my @result = ();
  for (my $key = 1; $key <= $proc; $key++) {
    if ($Proc{$key} == 0) {
      #print "Ressource $key free\n";
      push (@result, $key);
    } else {
      #print "Ressource $key not free\n";
    }
  }
  return @result;
}
