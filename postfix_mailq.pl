#!/usr/bin/perl
#
# Simple nagios plugin for Postfix mail queue which can handle several queues
#
# Author: Johan Hedberg, City Network Hosting AB <jh@citynetwork.se>
#

use strict;
use warnings;

use Getopt::Std;
use Carp;
use Data::Dumper;
use File::Find::Rule;

# Config
my $postfix_path = '/var/spool/postfix';
my @queues = qw(active incoming deferred hold);

# Parse argv
my %args;
my $usage = "Wrong argument list, needs both -c and -w!";
getopt('cw', \%args);
croak "$usage" unless defined($args{c});
croak "$usage" unless defined($args{w});

# For each queue
my $status = "OK";
my $retval = "";
foreach my $queue (@queues) {
	my $queue_output_name = $queue;
	my $queue_mails = get_queue_mails($postfix_path, $queue);
	chomp($queue_mails);
	$queue_mails =~ s/^\s+//;

	# Set warning/critical state
	if($queue ne "hold") {
		if(($status ne "CRITICAL") && ($queue_mails > $args{c})) {
			$status = "CRITICAL";
		}
		if(($status ne "CRITICAL") && ($status ne "WARNING") && ($queue_mails > $args{w})) {
			$status = "WARNING";
		}
	}

	# Set name uppercase in output for the warn/crit queues
	if(($queue_mails > $args{w}) || ($queue_mails > $args{c})) {
		$queue_output_name = uc $queue_output_name;
	}

	# Add to output
	$retval .= " $queue_output_name=$queue_mails,";
}
chop $retval;
print $status . ":" . $retval . "\n";

# Calculate number of mails in a given queue
sub get_queue_mails {
	my ($postfix_queues_path, $queue_name) = @_;
	my @files = File::Find::Rule->file()->in("$postfix_queues_path/$queue_name");
	return scalar @files;
}
