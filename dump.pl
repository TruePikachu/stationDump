#!/usr/bin/perl
use warnings;
use strict;
use XML::Simple qw(:strict);
use FileHandle;
use Data::Dumper;
use CatDatDB;
use XStringTable;
use Ware;
use Production;
use Station;

print STDERR "Loading cat/dat database...";
CatDatDB::loadDB($ARGV[0]);
print STDERR "\nLoading string table...";
XStringTable::init();
print STDERR "\nLoading wares...";
my %wares;
foreach my $wareRef (@{Ware::refList()}) {
	# TODO Reduce these matches
	# Don't want to regex golf for anything
	next unless defined $wareRef->{tags};
	next unless $wareRef->{tags} =~ /economy/;
	next if $wareRef->{id} =~ /^inv_/;
	next if $wareRef->{id} =~ /^shp_/;
	next if $wareRef->{id} =~ /^spe_/;
	next if $wareRef->{id} =~ /^stp_/;
	next if $wareRef->{id} =~ /^ecotest_/;
	next if $wareRef->{id} =~ /^upg_/;
	my $newWare = new Ware($wareRef);
	$wares{$newWare->id} = $newWare;
}

print STDERR "\nLoading production modules...";
my %prodModules;
foreach my $xmlName (CatDatDB::find(qr<assets/structures/Economy/production/macros/struct_econ_prod_.*_macro\.xml>)) {
	my $newProduction = new Production($xmlName);
	next unless defined $newProduction->name;
	$prodModules{$newProduction->id}=$newProduction;
}

print STDERR "\nCollecting stations...";
my @stationXmlList = CatDatDB::find(qr<assets/structures/build_trees/Macros/struct_bt_.*_macro\.xml>);
my %stations;
foreach my $xmlName (@stationXmlList) {
	my $newStation = new Station($xmlName);
	$stations{$newStation->id}=$newStation;
}

print STDERR "\nCollecting CVs";
my @cvXmlList = CatDatDB::find(qr<assets/props/SurfaceElements/Macros/buildmodule_stations_.*_macro\.xml>);
my %CVs;
foreach my $xmlName (@cvXmlList) {
	my $ref = XMLin(CatDatDB::read($xmlName),
		ForceArray	=> [qw /macro/],
		KeyAttr		=> {}
		);
	my $name = $ref->{macro}->[0]->{name};
	my @stationList;
	foreach my $stationRef (@{$ref->{macro}->[0]->{properties}->{builder}->{macro}}) {
		push @stationList, $stations{$stationRef->{ref}};
	}
	$CVs{$name}=\@stationList;
}
print STDERR "\n";

##########

my ($vesselID,$stationID,$stationNameNice,$prodLevel,$prodModuleName,$prodTimeNice,$multiNeed,$multiOptional,$multiOutput,$multiIntermediate,$multiSpecialists);

################################################################################
format LISTALL =
@*:
$vesselID
@|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$stationNameNice." Ware Summary (Fully Built)"
Specialists: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$multiSpecialists
~~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$multiSpecialists
..=====================================..=====================================..
|| @|||||||||||||||||||||||||||||||||| || @|||||||||||||||||||||||||||||||||| ||
   "INPUT",				  "OUTPUT"
||-------------------------------------++-------------------------------------||
|| ^|||||||||||||||||||||||||||||||||| || ^|||||||||||||||||||||||||||||||||| || ~~
   $multiNeed,				  $multiOutput
||=====================================##=====================================||
|| @|||||||||||||||||||||||||||||||||| || @|||||||||||||||||||||||||||||||||| ||
   "OPTIONAL",				  "INTERMEDIATE"
||-------------------------------------++-------------------------------------||
|| ^|||||||||||||||||||||||||||||||||| || ^|||||||||||||||||||||||||||||||||| || ~~
   $multiOptional,			  $multiIntermediate
''=====================================''=====================================''

.

format_name STDOUT "LISTALL";
foreach $vesselID (sort keys %CVs) {
foreach my $station (sort { $a->name cmp $b->name } @{$CVs{$vesselID}}) {
	$stationID = $station->id;
	$stationNameNice = $station->name;
	my %usedWares; # Need Optional Intermediate Produce
	my %usedSpecialists;
	foreach my $prodModule (@{$station->prodModuleNames}) {
		my $refProd = $prodModules{$prodModule->{macro}};
		next unless defined $refProd;
		foreach my $prodWare (keys %{$refProd->methods}) {
			my $refWareMaker = $wares{$prodWare}->productions->{$refProd->methods->{$prodWare}};
			markAll('P',$refWareMaker->{what},\%usedWares);
			markAll('N',$refWareMaker->{inputs},\%usedWares);
			markAll('O',$refWareMaker->{secondary},\%usedWares);
			if(defined $wares{$prodWare}->specialist) {
				$usedSpecialists{$wares{$prodWare}->specialist}=1;
			}
		}
	}
	next unless scalar keys %usedWares;
	my (@need,@optional,@intermediate,@output);
	foreach my $ware (sort keys %usedWares) {
		push @need,$wares{$ware}->name if $usedWares{$ware} eq 'N';
		push @optional,$wares{$ware}->name if $usedWares{$ware} eq 'O';
		push @intermediate,$wares{$ware}->name if $usedWares{$ware} eq 'I';
		push @output,$wares{$ware}->name if $usedWares{$ware} eq 'P';
	}
	$multiNeed = join "\r",sort @need;
	$multiOptional = join "\r",sort @optional;
	$multiIntermediate = join "\r",sort @intermediate;
	$multiOutput = join "\r",sort @output;
	$multiNeed = '(none)' if $multiNeed eq '';
	$multiOptional = '(none)' if $multiOptional eq '';
	$multiIntermediate = '(none)' if $multiIntermediate eq '';
	$multiOutput = '(none)' if $multiOutput eq '';
	$multiSpecialists = join ' ',sort keys %usedSpecialists;
	write STDOUT;
}
}

##########

sub multiWare {
	my $ref = shift;
	my $result = '';
	foreach my $ware (sort keys %{$ref}) {
		$result .= $ref->{$ware}." x ".$wares{$ware}->name . "\r";
	}
	chomp $result;
	if($result eq '') {
		$result = '(none)';
	}
	return $result
}

sub markWith {
	my ($val,$ware,$ref) = @_;
	my %mapping = (	N => {	N => 'N',
				O => 'N',
				I => 'I',
				P => 'I'},
			O => {	N => 'N',
				O => 'O',
				I => 'I',
				P => 'I'},
			I => {	N => 'I',
				O => 'I',
				I => 'I',
				P => 'I'},
			P => {	N => 'I',
				O => 'I',
				I => 'I',
				P => 'P'});
	if(defined $ref->{$ware}) {
		$ref->{$ware}=$mapping{$ref->{$ware}}->{$val};
	} else {
		$ref->{$ware}=$val;
	}
}

sub markAll {
	my ($val,$wares,$ref) = @_;
	foreach my $ware (keys %{$wares}) {
		markWith($val,$ware,$ref);
	}
}
