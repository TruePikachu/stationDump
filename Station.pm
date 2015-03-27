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
	my @normModules;
	foreach my $connection (@{$ref->{macro}->{connections}->{connection}}) {
		next unless defined $connection->{macro};
		next unless defined $connection->{macro}->{ref};
		my %nmodule;
		$nmodule{name}=$connection->{ref};
		$nmodule{macro}=$connection->{macro}->{ref};
		$nmodule{connection}=$connection->{macro}->{connection};
		if(defined $connection->{build}) {
			$nmodule{build}=$connection->{build}->{sequence} . '-' . $connection->{build}->{stage};
		} else {
			$nmodule{build} = 'N/A';
		}
		push @normModules, \%nmodule;
		next unless ($connection->{macro}->{ref} =~ /struct_econ_prod_.*_macro/);
		my %pmodule;
		$pmodule{macro}=$connection->{macro}->{ref};
		if(defined $connection->{build}) {
			$pmodule{build}=$connection->{build}->{sequence} . '-' . $connection->{build}->{stage};
		} else {
			$pmodule{build} = 'N/A';
		}
		push @prodModules, \%pmodule;
	}
	$self->{prodModuleNames} = \@prodModules;
	$self->{normModules} = \@normModules;
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

sub normModules {
	my ($self) = @_;
	return $self->{normModules};
}
1;
