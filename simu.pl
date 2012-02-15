#!/usr/bin/perl

use strict;
use File::Copy;
use Task;
use Comp;
use Proc;

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
our $global_time = 0;

# Array of processors :
my @Proc;

# Global list of tasks :
my @Work;

# Create the component objects and fill them, also create first tasks :
parse_file ($file, \@Work);

# Processing unit list initialisation :
for (my $key = 0; $key < $proc; $key++) {
  my $id = $key + 1;
  $Proc[$key] = new Processor ("P".$id, 1);;
}

# Create the ViTe trace file's header :
trace_init ($trace_file);

create_tasks(\@Work);

# Main simulator loop :
while ($iter > 0)
{
  # suppress ended tasks :
  delete_tasks ();

  # schedule available tasks onto free ressources :
  schedule_tasks ();

  # find the minimal amount of time to next event :
  my $min_time = min_time ();

  if ($min_time == 0) {
    exit 1;
  }

  # reduce components remaining time and set global time :
  move_forward ($min_time);
  $global_time += $min_time;

  # create new tasks in @Work :
  increment_counters ();
  create_tasks(\@Work);

  # next step :
  $iter -= $min_time;
}

close FILEHANDLER;

#######################
# Utility functions : #
#######################

# Create the ViTe trace file's header with a template and informations from
# application :
sub trace_init {
  my $trace_file = shift;
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

  foreach my $comp (keys (%Component::components)) {
    my $color = rand()." ".rand()." ".rand(); 
    print TRACEHANDLER "6 \"$comp\" \"SP\" \"$comp\" \"$color\"\n";
  }
}

# Parse application file and fill structures :
sub parse_file {
  my $file = shift;
  my $refWork = shift;
  my $line;

  open(FILEHANDLER, $file) or die $!;

  while ($line = <FILEHANDLER>) {
    if ($line !~ /^\#/) {
      last;
    }
  }

  chomp ($line);

  # First line contain each component, its incoming_needed and its execution
  # time :
  my @args = split (/,/, $line);
  while (@args) {
    my $name = shift (@args);
    my $inc  = shift (@args);
    my $time = shift (@args);
    my $concurrency = shift (@args);

    my $comp = new Component ($name, $time, $inc, $concurrency);
  }

  # space :
  $line = <FILEHANDLER>;
  if ($line !~ /^-\n/ ) {
    exit 0;
  }

  # comments :
  while ($line = <FILEHANDLER>) {
    if ($line !~ /^\#/) {
      last;
    }
  }

  # Next lines contain each component arrow to a son and its inserted coin in
  # one execution :
  #$line = <FILEHANDLER>;
  while ($line !~ /^-\n/) {
    chomp($line);
    @args = split (/,/, $line);
    my $name = shift (@args);

    while (@args) {
      my $dest = shift (@args);
      my $token = shift (@args);

      $Component::components{$name}->add_call ($dest, $token);
    }
    $line = <FILEHANDLER>;
  }

  # space :
  while ($line = <FILEHANDLER>) {
    if ($line !~ /^\#/) {
      last;
    }
  }
  chomp($line);

  # Last line contain the first tasks to schedule :
  @args = split (/,/, $line);
  foreach my $name (@args) {
    $Component::components{$name}->add_task ($refWork);
  }
}

# check the global counter to create new tasks :
sub create_tasks {
  my $refWork = shift;
  foreach my $comp (keys (%Component::components)) {
    $Component::components{$comp}->check_counter ($refWork);
  }
}

# increment global counters :
sub increment_counters {
  my @tasks = currently_executed ();
  for my $task (@tasks) {
    $task->add_coins ($global_time);
  }
}

# return the list of currently executed tasks :
sub currently_executed {
  my @result;
  my @workers = currently_working ();
  foreach my $worker (@workers) {
    push (@result, $worker->currently_executing ()); 
  }
  return @result;
}

# delete finished tasks from @Proc :
sub delete_tasks {
  my @tasks = currently_executed ();
  for my $task (@tasks) {
    if ($task->is_finished ()) {
      print TRACEHANDLER "12 $global_time \"SP\" \"$task->{processor}->{name}\"\n";  
      $task->{processor}->delete_task ();
    }
  }
}

# update every remaining_time and return the list of (newly?) free ressource
# (what about new tasks creation?)
sub move_forward {
  my $time = shift;

  foreach my $proc (currently_working ()) {
    $proc->move_forward ($time);
  }
}

# return the minimum time before next event :
sub min_time {
  my @tasks = currently_executed ();
  my $min = 0;

  foreach my $task (@tasks) {
    my $time = $task->min_time ();
    if (($min == 0) || ($time < $min)) {
      $min = $time;
    }
  }

  return $min;
}

# return the list of currently working ressources :
sub currently_working {
  my @result;
  foreach my $proc (@Proc) {
    if ($proc->is_working()) {
      push (@result, $proc);
    }
  }
  return @result;
}

# schedule tasks onto available ressources :
sub schedule_tasks {
  # get list of free ressources :
  my @freeR = free_ressources ();
  foreach my $proc (@freeR) {
    if (@Work) {
      my $task = shift @Work;
      $proc->execute ($task);
      print TRACEHANDLER "11 $global_time \"SP\" \"$proc->{name}\" \"$task->{type}\"\n";
    }
  }
}

# return the list of schedulable tasks on ONE ressource :
sub schedulable_tasks {
  return @Work;
}

# return the list of available ressources :
sub free_ressources {
  my @result = ();
  foreach my $proc (@Proc) {
    if (!$proc->is_working()) {
      push (@result, $proc);
    }
  }
  return @result;
}


