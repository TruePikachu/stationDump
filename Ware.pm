#!/usr/bin/perl
use warnings;
use strict;
use CatDatDB;
use XStringTable;
package Ware;
use XML::Simple qw(:strict);

sub refList {
	my $ref = XMLin(CatDatDB::read("libraries/wares.xml"),
		ForceArray	=> [qw/ware effect production/],
		KeyAttr		=> {effect => '+type'});
	return $ref->{ware};
}

sub new {
	my ($class,$ref) = @_;
	my $self = {
		id		=> $ref->{id},
		price		=> $ref->{price}->{average},
		pRange		=> [$ref->{price}->{min},$ref->{price}->{max}],
		name		=> XStringTable::expand($ref->{name}),
		description	=> XStringTable::expand($ref->{description}),
		specialist	=> $ref->{specialist},
		volume		=> $ref->{volume},
		size		=> $ref->{size},
	};
	my %productions;
	foreach my $prodRef (@{$ref->{production}}) {
		my %production;
		$production{time}=$prodRef->{time};
		my %outputs;
		$outputs{$ref->{id}} = $prodRef->{amount};
		$production{what}=\%outputs;
		my %inputs;
		foreach my $input (@{$prodRef->{primary}->{ware}}) {
			$inputs{$input->{ware}}=$input->{amount};
		}
		$production{inputs}=\%inputs;
		my %secondary;
		foreach my $second (@{$prodRef->{secondary}->{ware}}) {
			$secondary{$second->{ware}}=$second->{amount};
		}
		$production{secondary}=\%secondary;
		$productions{$prodRef->{method}}=\%production;
	}
	$self->{productions}=\%productions;

	bless $self,$class;
	return $self;
}

sub id {
	my ($self) = @_;
	return $self->{id};
}

sub price {
	my ($self) = @_;
	return $self->{price};
}

sub pRange {
	my ($self) = @_;
	return $self->{pRange};
}

sub name {
	my ($self) = @_;
	return $self->{name};
}

sub description {
	my ($self) = @_;
	return $self->{description};
}

sub specialist {
	my ($self) = @_;
	return $self->{specialist};
}

sub volume {
	my ($self) = @_;
	return $self->{volume};
}

sub size {
	my ($self) = @_;
	return $self->{size};
}

sub productions {
	my ($self) = @_;
	return $self->{productions};
}

1;
