#!/usr/bin/perl

##################################################################################################################
# 
# File         : fakeclick.pl
# Description  : Fetch a page and emulate click(s) on it
# Original Date: ~1996/8
# Author       : simran@dn.gs
#
##################################################################################################################

##################################################################################################################
#
# load all required modules
#
use strict;
use Getopt::Long;
use WWW::Mechanize;

###################################################################################################################
#
# CONSTANTS
#

##################################################################################################################
#
# GLOBALS
#

$| = 1;

#
#
##################################################################################################################


#################################################################################################################
#
# get the command line arguments
#

my $user_agent_alias = "Windows IE 6";
my $sleep_interval   = 60;
my $sleep_after      = 10;
my $text_regex       = "";
my $url_regex        = "";
my $verbose          = 0;
my $max_calls        = 300;
my $click_percentage = 0.5;
my $url              = "";

my $result = GetOptions(
                        "user_agent_alias=s" => \$user_agent_alias,
                        "sleep_interval=s"   => \$sleep_interval,
                        "sleep_after=s"      => \$sleep_after,
                        "text_regex=s"       => \$text_regex,
                        "url_regex=s"        => \$url_regex,
                        "verbose+"           => \$verbose,
                        "max_calls=s"        => \$max_calls,
                        "click_percentage=s" => \$click_percentage,
                        "url=s"              => \$url,
);

#
#
#
if (! $result) {
    &usage();
}
elsif ($sleep_interval !~ /^\d+$/) {
    &usage("Invalid --sleep_interval");
}
elsif ($sleep_after !~ /^\d+$/) {
    &usage("Invalid --sleep_after");
}
elsif ($text_regex && $url_regex) {
    &usage("You must specifiy only _one_ option from the following --text_regex\n"
          ."                                                       --url_regex\n"
    );
}
elsif (! ($text_regex || $url_regex) ) {
    &usage("You must specifiy _one_ option from the following --text_regex\n"
          ."                                                  --url_regex\n"
    );
}
elsif ($max_calls !~ /^\d+$/) {
    &usage("Invalid --max_calls");
}
elsif ($click_percentage !~ /^\d+(\.\d+)?$/) {
    &usage("Invalid --click_percentage");
}
elsif (! $url) {
    &usage("You must specify a --url option");
}

#
#
#
if ($user_agent_alias) {
    my $mech                = new WWW::Mechanize();
    my @known_agent_aliases = $mech->known_agent_aliases();
    my $agent_alias_ok      = 0;
  
    foreach my $alias (@known_agent_aliases) {
      if ($alias eq $user_agent_alias) {
          $agent_alias_ok = 1;
          last;
      }
    }
  
    if (! $agent_alias_ok) {
      &usage("Agent alias '$user_agent_alias' now known\n"
            ."Known aiiases are: ".join(', ', @known_agent_aliases));
  
    }
}
else {
    &usage("Must specify --user_agent_alias option");
}

#
#
#
&main();

#################################################################################################################
#
# MAIN
#
sub main {
    #
    #
    #
    my $mech           = new WWW::Mechanize();
    my $regex_key      = "";
    my $regex_value    = "";
    my $matching_calls = 0;
    my $num_clicked    = 0;
    my $start_time     = time;

    if    ($url_regex)  { $regex_key   = "url_regex";  $regex_value = $url_regex;  }
    elsif ($text_regex) { $regex_key   = "text_regex"; $regex_value = $text_regex; }
    else                { die "Unknown regex type";                                }

    #
    #
    #
    $mech->agent_alias($user_agent_alias);

    #
    #
    #
    for (my $calls = 1; $calls <= $max_calls; $calls++) {
        #
        #
        print "Fetching first url... please wait...\n" if ($calls == 0);

        #
        # Get the url...
        #
        $mech->get($url);

        #
        # if the url contained the content.. the increment matching_calls as well... 
        #
        if ($mech->find_link( $regex_key => qr/$regex_value/i )) {
            $matching_calls++;

            #
            # Click... if its time for us to click... 
            #
            if ( $matching_calls >= (($num_clicked + 1) * int(100 / $click_percentage)) ) {
                if ($mech->follow_link( $regex_key => qr/$regex_value/i )) {
                    $num_clicked++;
                }
            }
        }

        #
        # Work out when the next click is... 
        #
        my $next_click       = ($num_clicked + 1) * int(100 / $click_percentage);
        my $timenow          = time;
        my $time_delta       = $timenow - $start_time;
        my $seconds_per_call = $time_delta / $calls;

        #
        #
        if ($verbose) {
            print "Processing call            : $calls\n";
            print "Matching calls             : $matching_calls\n";
            print "Total calls                : $calls\n";
            print "Clicks                     : $num_clicked\n";
            print "Next Click At Matching Call: $next_click\n";
            print "Running time               : $time_delta\n";
            print "Average seconds per call   : $seconds_per_call\n";
            print "\n";
        }
        else {
            print "Processing call: $calls - matching: $matching_calls (total: $calls), clicks: $num_clicked "
                                                                                          ."(next click: $next_click)\t\r";
        }

        #
        # Sleep for a while if we need to...  
        #
        if ( ($calls % $sleep_after) == 0 ) {
            print "Sleeping for $sleep_interval seconds\n\n" if ($verbose);
            sleep($sleep_interval);
        }
    }

    #
    #
    #
    print "\n";
}

##################################################################################################################
#
# usage: Outputs the usage of this script.. 
#
sub usage {
  my $error = shift;
  
  if ($error) {
    print STDERR "Error\n";
    print STDERR "\n-----\n";
    print STDERR "$error\n";
    print STDERR "\n-----------------------------------------------------------------------\n";
    
  
  }

  print STDERR <<EOUSAGE;
  
Usage: $0 --url url 
                      <--text_regex regex|--url_regex regex> 
                      [--sleep_after integer] 
                      [--sleep_interval seconds] 
                      [--max_calls integer]
                      [--click_percentage float]
  
* --url                  : The url we are going to call to get content

* --text_regex           : The regular express that the content should match. We will emulate a click on the first
                           bit of content that is a link and matches the supplied regex.

* --url_regex            : The regular express that the content should match. We will emulate a click on the first
                           bit of content that is a link and matches the supplied regex.

* --sleep_after          : The amount of requests to service before we sleep for a while...  (default: $sleep_after)

* --sleep_interval       : The amount of time (in seconds) to sleep for after 'sleep_after' requests (default: $sleep_interval)

* --max_calls            : The maximum number of calls this script should make before exiting...  (default: $max_calls)

* --click_percentage     : The click percentage to emulate (default: $click_percentage)

Examples
--------

$0 --url "http://www.google.com/search?q=test" --url_regex www.test.com --verbose

EOUSAGE

  exit;
}


