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
use lib "/usr/local/libexec/nagios";
use utils qw(%ERRORS);

# Config
my $postfix_path = '/var/spool/postfix';
my $enable_perfdata = 1;
my @queues = qw(active incoming deferred hold);

# Parse argv
my %args;
my $usage = "Wrong argument list, needs both -c and -w!";
getopt('cw', \%args);
unless (defined($args{c})) {
	print_usage();
}
unless (defined($args{w})) {
	print_usage();
}

# Check that we got integers
if ($args{c} !~ /^\d+\z/) {
	print_usage();
}
if ($args{w} !~ /^\d+\z/) {
	print_usage();
}

# For each queue
my $status = "OK";
my %values;
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
	$values{$queue_output_name} = $queue_mails;
}
print $status;

# Generate output string
my $output = ":";
my @keys = sort {
	if(lc($a) eq 'hold') { return 1; }
	elsif (lc($b) eq 'hold') { return -1; }
	else { lc($a) cmp lc($b); }
} keys %values;
foreach (@keys) {
	$output .= " $_=$values{$_},";
}
chop($output);

# Add perfdata to output
if($enable_perfdata == 1) {
	$output .= " |";
	foreach (@keys) {
		$output .= " $_=" . $values{$_} . "[c];[$args{w}];[$args{c}]";
	}
}

# Output
print $output . "\n";

# Setting return code
exit $ERRORS{$status};


#
## Subroutines
#


# Calculate number of mails in a given queue
sub get_queue_mails {
	my ($postfix_queues_path, $queue_name) = @_;
	my @files = File::Find::Rule->file()->in("$postfix_queues_path/$queue_name");
	return scalar @files;
}

# Usage
sub print_usage {
	print "Usage: postfix_mailq.pl -c <crit> -w <warn>\n";
	print "-c and -w expects an integer each\n";
	exit $ERRORS{UNKNOWN};
}
