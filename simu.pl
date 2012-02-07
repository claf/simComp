#!/usr/bin/perl

use strict;
use File::Copy;
use Task;

# How many iteration of the main loop :
my $iter = shift;

# How many processors to simulate :
my $proc = shift;

# Which application file :
my $file = shift;

# Which trace file :
my $trace_file = shift;

# Header template trace file :
my $header_file = "header.vite";

# Starting global time is null :
my $global_time = 0;

# Array of processors :
my @Proc;

# How many calls to each component type has been received yet :
my %Incoming_counters;

# How many calls to each component type has to be received to create one :
my %Incoming_needed;

# Global list of tasks :
my @Work;

# Processing Time for every component :
my %Processing_Time;

# Hash of hashes representing each component bindings :
my %Calls;

#print "Running $iter iterations with $proc proccessing units";

# This function parses the application file and fill global structures
# (Processing_Time, Incoming_needed, Calls) and also create and insert the
# firsts tasks in the simulator :
parse_file ($file);

# Incoming counters initialisation :
foreach my $comp (keys (%Incoming_needed)) {
  $Incoming_counters{$comp} = 0;
}

# Processing unit list initialisation :
for (my $key = 1; $key <= $proc; $key++) {
  $Proc[$key] = 0;
}

# Create the ViTe trace file's header :
trace_init ($trace_file);

# Main simulator loop :
while ($iter)
{
  # suppress ended tasks :
  delete_tasks ();

  # schedule available tasks onto free ressources :
  schedule_tasks ();

  # find the minimal amount of time to next event :
  my $min_time = min_time ();
  
  if ($min_time == 0) {
    #print "\tmin time is 0?!\n";
  }

  # reduce components remaining time and set global time :
  move_forward ($min_time);
  $global_time += $min_time;

  # create new tasks in @Work :
  increment_counters ();
  create_tasks();

  # next step :
  $iter--;
}

close FILEHANDLER;

#######################
# Utility functions : #
#######################

# Create the ViTe trace file's header with a template and informations from
# application :
sub trace_init {
  my $trace_file = shift;
  my $color = "1.0 0.0 0.0"; 
  if ($header_file ne $trace_file) {
    copy ($header_file, $trace_file) or die "Copy failed: $!";
  } else {
    print "Can't have the same filename ($trace_file) as $header_file\n";
    exit 0;
  }

  open(TRACEHANDLER, '>>' . $trace_file) or die $!;

  print TRACEHANDLER "1 \"P\" \"0\" \"Processor\"\n";
  print TRACEHANDLER "3 \"SP\" \"P\" \"Processor State\"\n";

  for (my $proc = 1; $proc <= scalar @Proc; $proc++) {
    print TRACEHANDLER "7 0 \"P$proc\" \"P\" \"0\" \"P$proc\"\n";
  }

  foreach my $comp (keys (%Incoming_needed)) {
    print TRACEHANDLER "6 \"$comp\" \"SP\" \"$comp\" \"$color\"\n";
  }
}

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

    $Processing_Time{$comp} = $time;
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

  my $comp = new Task ($type, $Processing_Time{$type});
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
        #print "Added on coin in the $call Comp\n";
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
    push (@result, $Proc[$worker]); 
  }
  return @result;
}

# delete finished tasks from @Proc :
sub delete_tasks {
  my @workers = currently_working ();
  foreach my $worker (@workers) {
    if ($Proc[$worker]->{remaining_time} == 0) {
      #print "Ended task $Proc[$worker]->{name} at $global_time on $worker\n"; 
      print TRACEHANDLER "12 $global_time \"SP\" \"P$worker\"\n";
      $Proc[$worker] = 0;
    }
  }
}

# update every remaining_time and return the list of (newly?) free ressource
# (what about new tasks creation?)
sub move_forward {
  my $time = shift;

  my @currently_working = currently_working ();
  foreach my $key (@currently_working) {
    $Proc[$key]->{remaining_time} -= $time;
    foreach my $call (keys (%{$Proc[$key]->{calls_counters}})) {
      $Proc[$key]->{calls_counters}->{$call} -= $time;
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
    if ($Proc[$key] != 0) {
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
        $Proc[$ressource] = shift @Work;
        #print "Scheduled task $Proc[$ressource]->{name} on $ressource at time $global_time\n";
        print TRACEHANDLER "11 $global_time \"SP\" \"P$ressource\" \"$Proc[$ressource]->{name}\"\n";
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
    if ($Proc[$key] == 0) {
      #print "Ressource $key free\n";
      push (@result, $key);
    } else {
      #print "Ressource $key not free\n";
    }
  }
  return @result;
}


