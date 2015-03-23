#!/usr/bin/perl
use warnings;
use strict;
use XML::Simple qw(:strict);
use FileHandle;
use Data::Dumper;

# Load the cat/dat database
print STDERR "Loading cat/dat database";
my %fileInfo;
my %datHandle;
loadFileInfo();

print STDERR "\nLoading wares.xml...";
my $warexmlref = XMLin(readDat("libraries/wares.xml"),
		ForceArray	=> [qw/ware effect production/],
		KeyAttr		=> {effect => '+type'}
	);

print STDERR "\nLoading 0001-L044.xml...";
my $langref = XMLin(readDat("t/0001-L044.xml"),
		ForceArray	=> [qw /page t/],
		KeyAttr		=> {page => '+id',
				    t	 => '+id'}
	);

print STDERR "\nIndexing wares";
my %wares;
foreach my $wareRef (@{$warexmlref->{ware}}) {
	my %ware;
	$ware{id} = $wareRef->{id};
	$ware{name}=wareString($wareRef->{name});
	($ware{specialist})=$wareRef->{specialist} =~ /specialist(.*)/ if defined $wareRef->{specialist};
	$ware{specialist}='(none)' unless defined $ware{specialist};
	$ware{volume}=$wareRef->{volume};
	$ware{price}=$wareRef->{price}->{average};
	$ware{transport}=$wareRef->{transport};
	next if $ware{transport} eq 'ship';
	next unless defined $wareRef->{tags};
	next unless $wareRef->{tags} =~ /economy/;
	my %productions;
	foreach my $prodRef (@{$wareRef->{production}}) {
		my %production;
		$production{time}=$prodRef->{time};
		my %outputs;
		$outputs{$ware{id}} = $prodRef->{amount};
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
	$ware{productions}=\%productions;
	$wares{$ware{id}}=\%ware;
	print STDERR '.';
}

print STDERR "\nCollecting production modules";
my @prodModuleList = lsDat(qr<assets/structures/Economy/production/macros/struct_econ_prod_.*_macro\.xml>);
my %prodModules;
foreach my $xmlName (@prodModuleList) {
	my $ref = XMLin(readDat($xmlName),
		ForceArray	=> [qw /item/],
		KeyAttr		=> {item	=> '+ware'}
		);
	my %module;
	$module{id}=$ref->{macro}->{name};
	next unless defined $ref->{macro}->{properties}->{identification}->{name};
	$module{name}=string($ref->{macro}->{properties}->{identification}->{name});
	next unless defined $ref->{macro}->{properties}->{production}->{wares};
	my @waresMade = split / /,$ref->{macro}->{properties}->{production}->{wares};
	my %wareMethods;
	foreach my $ware (@waresMade) {
		if(defined $ref->{macro}->{properties}->{production}->{queue}->{item}->{$ware}->{method}) {
			$wareMethods{$ware}=$ref->{macro}->{properties}->{production}->{queue}->{item}->{$ware}->{method};
		} else {
			$wareMethods{$ware}='default';
		}
	}
	$module{makes}=\%wareMethods;
	$prodModules{$module{id}}=\%module;
	print STDERR '.';
}

print STDERR "\nCollecting stations";
my @stationXmlList = lsDat(qr<assets/structures/build_trees/Macros/struct_bt_.*_macro\.xml>);
my %stations;
foreach my $xmlName (@stationXmlList) {
	my $ref = XMLin(readDat($xmlName),
		ForceArray	=> [qw /connection/],
		KeyAttr		=> {}
		);
	my $stationRef = $ref->{macro};
	my %station;
	$station{id}=$stationRef->{name};
	$station{name}=string($stationRef->{properties}->{identification}->{name});
	my @prodModules;
	foreach my $connection (@{$stationRef->{connections}->{connection}}) {
		next unless defined $connection->{macro};
		next unless defined $connection->{macro}->{ref};
		next unless ($connection->{macro}->{ref} =~ /struct_econ_prod_.*_macro/);
		my %module;
		$module{macro}=$connection->{macro}->{ref};
		if(defined $connection->{build}) {
			$module{build}=$connection->{build}->{sequence} . '-' . $connection->{build}->{stage};
		} else {
			$module{build} = "N/A";
		}
		push @prodModules, \%module;
	}
	$station{prodModules} = \@prodModules;
	$stations{$station{id}}=\%station;
	print STDERR '.';
}

print STDERR "\n";

my ($stationID,$stationNameNice,$prodLevel,$prodModuleName,$prodTimeNice,$multiNeed,$multiOptional,$multiOutput,$multiIntermediate,$multiSpecialists);

format LISTALL =
@*
$stationID
@* Ware Summary (Fully built)
$stationNameNice
Specialists: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$multiSpecialists
~~           ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$multiSpecialists
@|||||||||||||||||||||||| || @|||||||||||||||||||||||| || @|||||||||||||||||||||||| || @||||||||||||||||||||||||
"NEED",				    "OPTIONAL",				"INTERMEDIATE",			    "OUTPUT"
^|||||||||||||||||||||||| || ^|||||||||||||||||||||||| || ^|||||||||||||||||||||||| || ^|||||||||||||||||||||||| ~~
$multiNeed,			    $multiOptional,			$multiIntermediate,		    $multiOutput


.

format_name STDOUT "LISTALL";
foreach $stationID (sort keys %stations) {
	$stationNameNice = $stations{$stationID}->{name};
	my %usedWares; # Need Optional Intermediate Produce
	my %usedSpecialists;
	foreach my $prodModule (@{$stations{$stationID}->{prodModules}}) {
		my $refProd = $prodModules{$prodModule->{macro}};
		next unless defined $refProd;
		foreach my $prodWare (keys %{$refProd->{makes}}) {
			my $refWareMaker = $wares{$prodWare}->{productions}->{$refProd->{makes}->{$prodWare}};
			markAll('P',$refWareMaker->{what},\%usedWares);
			markAll('N',$refWareMaker->{inputs},\%usedWares);
			markAll('O',$refWareMaker->{secondary},\%usedWares);
			if(defined $wares{$prodWare}->{specialist}) {
				$usedSpecialists{$wares{$prodWare}->{specialist}}=1 unless $wares{$prodWare}->{specialist} eq '(none)';
			}
		}
	}
	next unless scalar keys %usedWares;
	my (@need,@optional,@intermediate,@output);
	foreach my $ware (sort keys %usedWares) {
		push @need,$wares{$ware}->{name} if $usedWares{$ware} eq 'N';
		push @optional,$wares{$ware}->{name} if $usedWares{$ware} eq 'O';
		push @intermediate,$wares{$ware}->{name} if $usedWares{$ware} eq 'I';
		push @output,$wares{$ware}->{name} if $usedWares{$ware} eq 'P';
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

##########

sub loadFileInfo {
	my @catFileList;
	{
		opendir STEAMDIR,"steamdir" or die "Can't open steamdir";
		while(my $file = readdir STEAMDIR) {
			push @catFileList,"steamdir/$file" if $file =~ /\.cat$/;
		}
	}
	foreach my $catPath (sort @catFileList) {
		my $datPath = $catPath;
		$datPath =~ s/cat$/dat/;
		open my $handle, "< $datPath";
		$datHandle{$datPath}=$handle;
		open CATFILE, "< $catPath";
		my $datSeek = 0;
		while(my $parse = <CATFILE>) {
			chomp $parse;
			my ($fName,$fSize,$fDate,$fHash) = $parse =~ /^(.*) ([0-9]*) ([0-9]*) ([0-9a-f]{32})$/;
			my %info = (name => $fName,
				    size => $fSize,
				    date => $fDate,
				    hash => $fHash,
				    file => $datPath,
				    seek => $datSeek);
			$fileInfo{$fName}=\%info;
			$datSeek += $fSize;
		}
		print STDERR '.';
	}
}

sub readDat {
	my $name = shift;
	die "File $name not found" unless defined $fileInfo{$name};
	my $handle = $datHandle{$fileInfo{$name}->{file}};
	seek($handle,$fileInfo{$name}->{seek},0);
	my $data;
	read($handle,$data,$fileInfo{$name}->{size});
	return $data;
}

sub lsDat {
	my $pattern = shift;
	my @result;
	foreach my $name (keys %fileInfo) {
		push @result,$name if $name =~ $pattern;
	}
	return sort @result;
}

##########

sub wareString {
	my $ref = string(shift);
	if($ref =~ /{.*} {.*}/) {
		my ($name,$mark) = split / /,$ref;
		$ref = string($name) . ' ' . string($mark);
	}
	return $ref;
}

sub string {
	my $ref = shift;
	my ($page,$id) = $ref =~ /{([0-9]*),([0-9]*)}/;
	return $ref unless defined $id;
	return $langref->{page}->{$page}->{t}->{$id}->{content};
}

sub multiWare {
	my $ref = shift;
	my $result = '';
	foreach my $ware (sort keys %{$ref}) {
		$result .= $ref->{$ware}." x ".$wares{$ware}->{name} . "\r";
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
