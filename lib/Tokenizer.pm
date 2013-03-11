package Tokenizer;

use strict;
use warnings;
use utf8;
use open ':utf8';
binmode(STDIN,  "utf8");
binmode(STDOUT, "utf8");
binmode(STDERR, "utf8");

use File::Find;
use File::Spec;

sub all {
  my ($working_dir) = @_;

  # the list of files to tokenize
  our @files;

  # get files
  find(\&wanted, $working_dir);
  sub wanted {
    push @files, File::Spec->rel2abs($_) if -f $_;
  }

  my $candidates = &tokenize(\@files);

}



sub tokenize {
  print "Segmentation des fichiers...\n";
  my ($files) = @_;

  # characters which have to be cut off at the beginning of a word
  my $cut_begin='\[«[{(\\`"‚„†‡‹*‘’“”•–—›\-';

  # characters which have to be cut off at the end of a word
  my $cut_end=']\]}\'\`\"),;:\!\?\%‚„…†‡‰‹*‘’“”•–—›»\.\-';

  # french
  my $clitic_begin = '[dcjlmnstDCJLNMST]\'|[Qq]u\'|[Jj]usqu\'|[Ll]orsqu\'';
  my $clitic_end   = '-t-elles?|-t-ils?|-t-on|-ce|-elles?|-ils?|-je|-la|-les|-leur|-lui|-mêmes?|-m\'|-moi|-nous|-on|-toi|-tu|-t\'|-vous|-en|-y|-ci|-l|-l[aà]';

  # create a list storing candidates for every file
  my @texts;


  foreach my $file(@$files) {
    open(FILE, $file) or die;

    # create a hash to store each words we find;
    my %text;
    $text{ title } = $file;

    my %words;

    while (<FILE>) {
      # replace newlines and tab characters with blanks
      tr/\n\t/  /;
      # replace strange apostrophe
      tr/`’´/'/;
      # remove strange chars
      tr/­/-/;
      tr/ / /;

      my @words = split(/,| |…|;|\//);
      foreach my $word (@words) {
	if ($word =~ /^<.*>$/) {
	  $text{ url } = $word;
	  next;
	}

	$word =~ s!\pS!!g;

	$word =~ s!([$cut_end])+$!!g;
	$word =~ s/^([$cut_begin])+(.)/$2/;
	$word =~ s/^([$cut_end])+(.)/$2/;

	$word =~ s!^$clitic_begin!!;
	$word =~ s!$clitic_end$!!;

	$words{ $word }++;
      }
    }
    close(FILE);
    $text{ content } = \%words;

    push @texts, \%text;
  }


  return \@texts;

}

1;
