package Compare;

use strict;
use warnings;
use utf8;
use open ':utf8';
binmode(STDIN,  "utf8");
binmode(STDOUT, "utf8");
binmode(STDERR, "utf8");

use File::Find;
use File::Spec;
use Tie::File;

sub acquire_known {
  my ($known_file, $accepted_file) = @_;

  # Here we merge the known forms,
  # and the one we decided to accept
  my @known;

  open(KNOWN, '<', $known_file) or die;
  while (<KNOWN>) {
    chomp($_);
    push @known, $_ ;
  }
  close(KNOWN);

  open(ACCEPTED, '<', $accepted_file) or die;
  while (<ACCEPTED>) {
    chomp($_);
    push @known, $_ ;
  }
  close(ACCEPTED);

  return \@known;
}

sub clean_hash {
  my ($texts) = @_;

  print "Nettoyage des mots...\n";
  # print @$texts; #= hash

  foreach my $text (@$texts) {
    my $h_words = $text->{content};

    foreach my $word(keys %$h_words ) {
     delete $text->{content}{$word}  if length($word) < 2;
     # 1 char long is not event a word!
     delete $text->{content}{$word} if length($word) < 2;

     # and more than 75 chars is way too long
     delete $text->{content}{$word} if length($word) > 75;

     # rm figures
     delete $text->{content}{$word} if $word =~ /^\d*$/;

     # rm centuries
     delete $text->{content}{$word} if $word =~ /^((\d+)|([ivx]+))(e|i?er|i?[eè]me)$/i;

     # remove hours and sport results
     delete $text->{content}{$word} if $word =~ /\d{1,2}[h:-]\d{0,2}/i;

     # remove things that are not part of a word
     delete $text->{content}{$word} if $word =~ /[«»<>:\?!(\.{3})]/;

     # remove digits combinaisons and units
     delete $text->{content}{$word} if $word =~ /^[\$\+\-]?\d+[,\.-\/]?(\d+)?[e€]?\.?$/i;

     # remove units
     delete $text->{content}{$word} if $word =~ /^\d+[ck]?[mvw][23²]?$/i;

     # remove words with multiple dashes
     delete $text->{content}{$word} if $word =~ /^(\-[^\-]){3}/i;
   }
  }

  return $texts;

}

sub compare {
  my ($texts,$known_forms,$accepted_file) = @_;

  # convert the list to a hash,
  # this is way way faster than grep
  # note we also capitalize forms

  # PLEASE NOTE
  # perl's map will result in a HUGE memory usage
  # more than 1G...
  # my %known = (
  # 	       map { $_ => 1 } @$known_forms,
  # 	       map { ucfirst($_) => 1 } @$known_forms,
  # 	       map { uc($_) => 1 } @$known_forms
  # 	      );
  my %known;
  foreach my $known (@$known_forms) {
    $known{ $known } = 1;
    $known{ ucfirst($known) } = 1;
    $known{ uc($known) } = 1;
  }


  foreach my $text (@$texts) {
    my $h_words = $text->{content};

    my $context;
    open(F, '<', $text->{title});
    while (<F>) {
      $context .= $_;
    }
    close(F);

    # print "Comparaison de " . (keys %$h_words) . " éléments...\n";

    # create a list of unknown words
    my @unknown;
    foreach my $word(sort (keys %$h_words) ) {
      push @unknown, $word if !exists $known{ $word }
    }

    # check array is not empty
    if (scalar(@unknown) > 0) {
      print $context . "\n";
      print "Je ne connais pas:\n";
      for (my $i = 0; $i < @unknown; $i++) {
	print "$i) $unknown[$i]\n";
      }

      # we place accepted words in a file
      print "Quels mots souhaitez ignorer et ajouter à la liste ?\n";
      my @user_accepted = split(/,? |\n/, <STDIN>);
      print join(", ", @user_accepted);
      open(ACCEPTED, '>>', $accepted_file) or die;
      foreach my $number (@user_accepted) {
	print ACCEPTED $unknown[$number] . "\n";
      }
      close(ACCEPTED);
    }

  }

}


1;
