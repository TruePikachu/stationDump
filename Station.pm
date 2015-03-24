#!/usr/bin/perl
use warnings;
use strict;
use CatDatDB;
use XStringTable;
package Station;
use XML::Simple qw(:strict);

sub new {
	my ($class,$path) = @_;
	my $ref = XMLin(CatDatDB::read($path),
		ForceArray	=> [qw /connection/],
		KeyAttr		=> {}
	);
	my $self = {
		id	=> $ref->{macro}->{name},
		name	=> XStringTable::expand($ref->{macro}->{properties}->{identification}->{name}),
	};
	my @prodModules;
	foreach my $connection (@{$ref->{macro}->{connections}->{connection}}) {
		next unless defined $connection->{macro};
		next unless defined $connection->{macro}->{ref};
		next unless ($connection->{macro}->{ref} =~ /struct_econ_prod_.*_macro/);
		my %module;
		$module{macro}=$connection->{macro}->{ref};
		if(defined $connection->{build}) {
			$module{build}=$connection->{build}->{sequence} . '-' . $connection->{build}->{stage};
		} else {
			$module{build} = 'N/A';
		}
		push @prodModules, \%module;
	}
	$self->{prodModuleNames} = \@prodModules;
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

sub prodModuleNames {
	my ($self) = @_;
	return $self->{prodModuleNames};
}

1;
