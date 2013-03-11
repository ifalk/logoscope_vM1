package WebContent;

use strict;
use warnings;
use utf8;
binmode(STDIN,  'utf8');
binmode(STDOUT, 'utf8');
binmode(STDERR, 'utf8');

use LWP::UserAgent;
use URI::URL;
use HTML::LinkExtor;
use HTML::TreeBuilder;
#use HTML::Parser;
use XML::RSS::Parser;
use File::Path qw(make_path);
use Date::Manip;
use Date::Calc qw(Delta_Days);

# initialize the useragent
# it will be used a lot
our $ua = LWP::UserAgent->new;
$ua->agent('Mozilla/6.0 (compatible;)');

# create a main sub to do everything
sub all {
  my ($websites,$tmp_dir) = @_;

  # launch eveything
  $websites = &get_websites_rss($websites);
  &rss_pages_to_fetch($websites);
  &download($websites, $tmp_dir);
}


# build a hash associating website's name => @rss_pages
sub get_websites_rss {
  my ($websites) = @_;

  # first
  # get a list of websites
  # stored in a text file named "websites"
  my @websites ;

  open(WEBSITES, '<', $websites) or die;
  while (<WEBSITES>) {
    chomp $_ ;
    push @websites, $_ if $_ !~ /^#|^$/; # check it is not commented nor empty line
  }
  close(WEBSITES);

  # Since we are interested in the rss of those webpages,
  # we create a hash
  my %websites;

  # now go to their rss
  foreach my $website(@websites) {
    print "Getting rss for $website\n";

    # go to the rss page, usually website/rss
    # BEWARE
    # if you want to parse websites where rss are in a different location
    # remove the following line
    # AND edit the websites file accordingly
    my $rss_page = $website . "rss/";

    # now extract links and links only
    # and put them in a new array
    my @links;

    # prevent the sub in sub mistakes
    # by declaring anonymous sub
    my $links_sub = sub {
      my($tag, %attr) = @_;
      if ($tag eq 'a') { # just <a href>;

	# convert hash to usable scalar var
	foreach my $link(values %attr) {
	  # check it is not a redirection or html file
	  # and that we talk about rss
	  if ($link !~ /=http|html?$/ && $link =~ m,/rss/[^#]|^$,) {
	    # print "$link\n";
	    push(@links, $link);
	  }
	}
      }
    };

    # Make the parser.
    my $parser = HTML::LinkExtor->new(\&$links_sub,$rss_page);

    # Request document and parse it as it arrives
    my $res = $ua->request(HTTP::Request->new(GET => $rss_page),
			   sub {$parser->parse($_[0])});

    # remove duplicates
    # quick and dirty way
    my %tmp;
    @tmp{@links} = ();
    @links = sort keys %tmp;

    # Put links into the hash
    $websites{ $website } = \@links;
  }
  return \%websites;
}


# modify the hash to the following:
# %website = name => %category
# where %category => @list_of_pages
sub rss_pages_to_fetch {
  my($websites) = @_;

  # create today array,
  # used for comparaison
  my $today = gmtime();
  my @today = UnixDate($today,"%Y","%m","%d");

  while (my ($website, $rss_page) = each %$websites) {
    # print $website . "\n";
    my %category_content;
    # go to every rss page
    foreach my $url(@$rss_page) {
      my %title_link;
      my $parser = XML::RSS::Parser->new;
      my $feed = $parser->parse_uri($url);

      # for some pages parser may not work
      # so check it answered something
      if ($feed) {
  	# get the title of the rss feed
  	my $query = $feed->query('/channel/title');
  	my $category = $query->text_content;

  	foreach my $item ( $feed->query('//item') ) {

  	  # compare the pubDate with today
  	  my $pubDate = $item->query('pubDate')->text_content;
  	  $pubDate = ParseDate($pubDate);

  	  # figaro madame (and maybe others) won't respect pubDate standards,
  	  # so we prevent such a case
  	  if ($pubDate) {
  	    my @pubDate = UnixDate($pubDate,"%Y","%m","%d");

  	    # if post is one day old, we want it
  	    if (Delta_Days(@pubDate,@today) == 1) {
  	      my $title = $item->query('title')->text_content;
  	      my $url = $item->query('link')->text_content;
	      $title_link{ $title } = $url if $title ne "";
  	    }
  	  }
  	  else {print "$0: Date invalide pour $url: ";
  		print $item->query('pubDate')->text_content . "\n";}
  	}
  	# check %title_link is not empty
  	$category_content{ $category } = \%title_link if (%title_link);
      }
      else {
	print "$0: Impossible de parser $url\n";
      }
      $$websites{ $website } = \%category_content;
    }
  }
}

sub download {
  my ($websites,$root_path) = @_;

  make_path($root_path) ;


  while (my ($website, $categories) = each %$websites) {
    print "Téléchargement des flux de $website";

    # remove http://www
    $website =~ s!http://www\.!!;

    my $site_path = $root_path . "/" . $website;
    make_path($site_path)
      or die "Died! Le répertoire existe-t-il déjà ?";

    while (my ($name, $content) = each %$categories) {
      my $category_path = $site_path . "/" . $name;
      make_path($category_path) or die $!;
      while (my ($title, $url) = each %$content) {
	my $filename = $title;
	# remove any 'strange' char from this string
	$filename =~ s!/!_-_!g;  # needed! (or else will try to create a subdir)
	$filename =~ s![ ' ]!_!g;
	$filename =~ s![\.,:\!?%]!!g;

	# where to print the results
	our $output = $category_path . "/" . $filename;

	# fetch content
	my $content = $ua->get($url)->decoded_content;
	# print $url . "\n";

	open(OUTPUT, '>>:utf8', $output)   || die "$!: $output";

	my $tree = HTML::TreeBuilder->new();
	$tree->parse($content);

	$tree->look_down( sub {

	  my ($tree) = @_;

	  return if $tree->tag() ne 'div';

	  # Le monde
	  if ($tree->attr('itemprop')) {
	    foreach ($tree->look_down( '_tag', 'p' )) {
	      print OUTPUT $_->as_text . "\n";
	    }
	  }
	  # Le figaro, Les echos
	  if ($tree->attr('class')) {
	    if ($tree->attr('class') eq 'texte') {
	      foreach ($tree->look_down( '_tag', 'p' )) {
		print OUTPUT $_->as_text . "\n";
	      }
	    }
	  }
	  # Liberation, Figaro (bis), blog Le Monde
	  if ($tree->attr('class')) {
	    if ($tree->attr('class') =~ /((figaro|entry)-content)|article/) {
	      foreach ($tree->look_down( '_tag', 'p' )) {
		print OUTPUT $_->as_text . "\n";
	      }
	    }
	  }
	  # Le figaro, vins
	  if ($tree->attr('id')) {
	    if ($tree->attr('id') eq 'content-text') {
	      foreach ($tree->look_down( '_tag', 'p' )) {
		print OUTPUT $_->as_text . "\n";
	      }
	    }
	  }
	});

	$tree->eof;
	$tree->delete;


	# print url in EOF
	print OUTPUT "\n<$url>\n";
	close(OUTPUT);
      }
    }
  }
}
