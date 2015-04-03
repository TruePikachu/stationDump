#!/usr/bin/perl
use warnings;
use strict;
use CatDatDB;
package XStringTable;
use XML::Simple qw(:strict);
our %table;	# {page}->{entry} = string
sub init {
	my $langsrc = shift;
	$langsrc='t/0001-L044.xml' unless defined $langsrc;
	my $ref;
	eval {
		$ref = XMLin(CatDatDB::read($langsrc),
			ForceArray	=> [qw /page t/],
			KeyAttr		=> {page => '+id',
					    t	 => '+id'});
		1;
	} or do {
		my $e = $@;
		print "XStringTable::init: XML Parse Error:\n$e\n";
		print "File information (from CatDatDB):\n";
		print CatDatDB::info($langsrc),"\n";
		die;
	};
	foreach my $pageNum (keys %{$ref->{page}}) {
		my $pageRef = $ref->{page}->{$pageNum};
		my %page;
		foreach my $entryNum (keys %{$pageRef->{t}}) {
			$page{$entryNum}=$pageRef->{t}->{$entryNum}->{content};
		}
		$table{$pageNum}=\%page;
	}
}

sub lookup {
	my ($page,$entry) = @_;
	return $table{$page}->{$entry};
}

sub expand {
	my $what = shift;
	return $what unless defined $what;
	for(;;) {
		# Search for any reference IDs in the string
		my ($page,$entry) = $what =~ /\{([0-9]*), *([0-9]*)\}/p;
		return $what unless defined $page;
		$what = ${^PREMATCH} . $table{$page}->{$entry} . ${^POSTMATCH};
	}
}

1;
