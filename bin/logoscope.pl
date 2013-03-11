#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
binmode(STDIN,  'utf8');
binmode(STDOUT, 'utf8');
binmode(STDERR, 'utf8');

use Date::Manip;

require lib::WebContent;
require lib::Tokenizer;
require lib::Compare;
require lib::Edit;

# the files where are the known forms
my $known_file    = "lib/known_forms";
my $accepted_file = "lib/accepted_forms";

# get current date
my $today = gmtime();
my @today = UnixDate($today,"%Y","%m","%d");


# path to the file storing websites list
my $websites = "websites";

# path of working dir,
# you may want to overwrite it
my $tmp_dir  = "tmp_" . join("", @today);
# if you don't want to download everything but use an already existing dir
# uncomment the following
# $tmp_dir = "tmp_20120331/";
# and comment &WebContent::all($websites,$tmp_dir);

&WebContent::all($websites,$tmp_dir);
my $words = &Tokenizer::all($tmp_dir);

my $known_forms = &Compare::acquire_known($known_file,$accepted_file);
$words = &Compare::clean_hash($words);
$words = &Compare::compare($words,$known_forms,$accepted_file);

