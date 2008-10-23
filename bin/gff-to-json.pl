#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Getopt::Long;
use Bio::DB::SeqFeature::Store;
use JsonGenerator;

my ($path, $trackLabel, $key, $cssClass);
my $autocomplete = "none";
my $outdir = "data";
my ($getType, $getPhase, $getSubs, $getLabel) = (0, 0, 0, 0);
GetOptions("gff=s" => \$path,
	   "out=s" => \$outdir,
	   "tracklabel=s" => \$trackLabel,
	   "key=s" => \$key,
	   "cssclass=s" => \$cssClass,
	   "autocomplete=s" => \$autocomplete,
	   "type" => \$getType,
	   "phase" => \$getPhase,
	   "subs" => \$getSubs,
	   "featlabel" => \$getLabel);

if (!defined($path)) {
    print <<USAGE;
USAGE: $0 --gff <gff file> [--out <output directory>] --tracklabel <track identifier> --key <human-readable track name> [--cssclass <CSS class for displaying features>] [--autocomplete none|label|alias|all] [--type] [--phase] [--subs] [--featlabel]

    --out: defaults to "data"
    --cssclass: defaults to "feature"
    --autocomplete: make these features searchable by their "label", by their "alias"es, both ("all"), or "none".
    --type: include the type of the features in the json
    --phase: include the phase of the features in the json
    --subs:  include subfeatures in the json
    --featlabel: include a label for the features in the json
USAGE
}

my @refSeqs = @{JsonGenerator::readJSON("$outdir/refSeqs.js", [], 1)};

die "run prepare-refseqs.pl first to supply information about your reference sequences" if $#refSeqs < 0;

sub gffLabelSub {
    return $_[0]->display_name if ($_[0]->can('display_name') && defined($_[0]->display_name));
    if ($_[0]->can('attributes')) {
	return $_[0]->attributes('load_id') if $_[0]->attributes('load_id');
	return $_[0]->attributes('Alias') if $_[0]->attributes('Alias');
    }
    #return eval{$_[0]->primary_tag};
}

my $db = Bio::DB::SeqFeature::Store->new(-adaptor => 'memory',
					 -dsn     => $path);

foreach my $seqInfo (@refSeqs) {
    my $seqName = $seqInfo->{"name"};
    print "\nworking on seq $seqName\n";

    my @features = $db->features("-seqid" => $seqName);

    print "got $#features features\n";

    if (!defined($trackLabel)) { $trackLabel = $features[0]->primary_tag };

    my %style = ("-autocomplete" => $autocomplete,
		 "-type"         => $getType,
		 "-phase"        => $getPhase,
		 "-subfeatures"  => $getSubs,
		 "-class"        => $cssClass,
		 "-label"        => $getLabel ? \&gffLabelSub : 0,
                 "-key"          => defined($key) ? $key : $trackLabel);

    JsonGenerator::generateTrack(
				 $trackLabel, $seqName,
				 "$outdir/$seqName/$trackLabel/",
                                 10000,
				 #"$outdir/$seqName/$trackLabel.names",
				 \@features, \%style,
				 [], []
				);

    JsonGenerator::modifyJSFile("$outdir/trackInfo.js", "trackInfo",
		 sub {
		     my $trackList = shift;
		     my $i;
		     for ($i = 0; $i <= $#{$trackList}; $i++) {
			 last if ($trackList->[$i]->{'label'} eq $trackLabel);
		     }
		     $trackList->[$i] =
		       {
			'label' => $trackLabel,
			'key' => $style{-key},
			'url' => "$outdir/{refseq}/$trackLabel/trackData.json",
			'type' => "SimpleFeatureTrack",
		       };
		     return $trackList;
		 });
}