#!/usr/bin/perl
use warnings;
use strict;

package CatDatDB;
our %fileInfo;	# Information for each file
our %datHandle;	# Handle for each .dat file

sub loadDB {
	my $steamdir = shift;
	$steamdir = 'steamdir' unless defined $steamdir;
	my @catFileList;
	opendir STEAMDIR,$steamdir or die "Can't open $steamdir\n";
	while(my $file = readdir STEAMDIR) {
		push @catFileList,"$steamdir/$file" if $file =~ /\.cat$/;
	}
	foreach my $catPath (sort @catFileList) {
		my $datPath = $catPath;
		$datPath =~ s/cat$/dat/;
		open my $handle,'<',$datPath;
		$datHandle{$datPath}=$handle;
		open CATFILE,'<',$catPath;
		my $datSeek=0;
		while(my $parse = <CATFILE>) {
			chomp $parse;
			my ($fName,$fSize,$fDate,$fHash) = $parse =~ /^(.*) ([0-9]*) ([0-9]*) ([0-9a-f]{32})$/;
			my %info = (	name	=> $fName,
					size	=> $fSize,
					date	=> $fDate,
					hash	=> $fHash,
					file	=> $datPath,
					seek	=> $datSeek);
			$fileInfo{$fName}=\%info;
			$datSeek += $fSize;
		}
	}
}

sub read {
	my $name = shift;
	die "File $name not found" unless defined $fileInfo{$name};
	my $handle = $datHandle{$fileInfo{$name}->{file}};
	seek($handle,$fileInfo{$name}->{seek},0);
	my $data;
	read($handle,$data,$fileInfo{$name}->{size});
	return $data;
}

sub find {
	my $pattern = shift;
	my @result;
	foreach my $name (keys %fileInfo) {
		push @result,$name if $name =~ $pattern;
	}
	return sort @result;
}

1;
