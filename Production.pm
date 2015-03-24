#!/usr/bin/perl
use warnings;
use strict;
use CatDatDB;
use XStringTable;
package Production;
use XML::Simple qw(:strict);

sub new {
	my ($class,$path) = @_;
	my $ref = XMLin(CatDatDB::read($path),
		ForceArray	=> [qw /item/],
		KeyAttr		=> {item	=> '+ware'}
	);
	my $self = {
		id	=> $ref->{macro}->{name},
		name	=> XStringTable::expand($ref->{macro}->{properties}->{identification}->{name}),
	};
	my %wareMethods;
	if(defined $ref->{macro}->{properties}->{production}->{wares}) {
		foreach my $ware (split / /,$ref->{macro}->{properties}->{production}->{wares}) {
			$wareMethods{$ware}=$ref->{macro}->{properties}->{production}->{queue}->{item}->{$ware}->{method};
			$wareMethods{$ware}='default' unless defined $wareMethods{$ware};
		}
	}
	$self->{methods} = \%wareMethods;
	bless $self,$class;
	return $self;
}

sub id {
	my ($self) = @_;
	return $self->{id};
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

sub methods {
	my ($self) = @_;
	return $self->{methods};
}

1;
