#!/usr/bin/env perl
package DarkPAN::Module::Docs;

use strict;
use warnings;

use Pod::Extract;
use Pod::Markdown;
use Text::Markdown::Discount qw(markdown);
use Scalar::Util qw(openhandle);
use English qw(-no_match_vars);

########################################################################
sub new {
########################################################################
  my ( $class, $text ) = @_;

  my $fh;

  if ( ref $text && openhandle $text ) {
    $fh = $text;
    local $RS = undef;
    $text = <$fh>;
    close $fh;
  }
  elsif ( ref $text ) {
    $text = ${$text};
  }

  my $self = bless { text => $text }, $class;

  return $self->parse_pod();
}

########################################################################
sub parse_pod {
########################################################################
  my ($self) = @_;

  my $text = $self->{text};

  my $fh = IO::Scalar->new( \$text );

  my @result = extract_pod( $fh, { markdown => 1 } );

  close $fh;

  @{$self}{qw(pod code sections markdown)} = @result;

  if ( $self->{pod} ) {
    $self->{html} = Text::Markdown::Discount::markdown( $self->{markdown} );
  }

  return $self;
}

########################################################################
package DarkPAN::Utils;
########################################################################

use strict;
use warnings;

use Archive::Tar;
use Class::Accessor::Validated qw(setup_accessors);
use Data::Dumper;
use English qw(no_match_vars);
use File::Basename qw(fileparse);
use Getopt::Long qw(:config no_ignore_case);
use HTTP::Request;
use IO::Scalar;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use LWP::UserAgent;
use List::Util qw(none);
use Log::Log4perl qw(:easy);
use Log::Log4perl::Level;
use Pod::Usage;

use Readonly;
Readonly our $BASE_URL => 'https://cpan.treasurersbriefcase.com';

use parent qw(Class::Accessor::Validated);

our %ATTRIBUTES = (
  logger        => 0,
  log_level     => 1,
  package       => 0,  # Archive::Tar of unzip packag
  module_index  => 0,  # distribution tarball indexed list of contents
  darkpan_index => 0,  # distribution list (raw)
  help          => 0,
  base_url      => 1,
  module        => 0,
);

setup_accessors( keys %ATTRIBUTES );

caller or __PACKAGE__->main();

########################################################################
sub find_module {
########################################################################
  my ( $self, $module ) = @_;

  my $module_index = $self->get_module_index;

  foreach my $p ( keys %{$module_index} ) {
    next if none { $_ eq $module } @{ $module_index->{$p} };

    return $p;
  }

  return;
}

########################################################################
sub extract_file {
########################################################################
  my ( $self, $file ) = @_;

  return $self->get_package->get_content($file);
}

########################################################################
sub extract_module {
########################################################################
  my ( $self, $package, $module ) = @_;

  $package =~ s{D/DU/DUMMY/(.*)[.]tar[.]gz$}{$1}xsm;

  my $file = $module;

  $file =~ s/::/\//xsmg;

  return $self->extract_file( sprintf '%s/lib/%s.pm', $package, $file );
}

########################################################################
sub fetch_darkpan_index {
########################################################################
  my ($self) = @_;

  my $file = '02packages.details.txt.gz';

  my $index_url = sprintf '%s/orepan2/modules/%s', $self->get_base_url, $file;

  my $ua  = LWP::UserAgent->new;
  my $req = HTTP::Request->new( GET => $index_url );
  my $rsp = $ua->request($req);

  my $index = q{};

  die Dumper( [ rsp => $rsp ] )
    if !$rsp->is_success;

  my $index_zipped = $rsp->content;

  gunzip( \$index_zipped, \$index )
    or die "unzip failed: $GunzipError\n";

  $self->set_darkpan_index($index);

  $self->_create_module_index;

  return $self;
}

########################################################################
sub fetch_package {
########################################################################
  my ( $self, $package_name ) = @_;

  my $logger = $self->get_logger;

  my $package_url = sprintf '%s/orepan2/authors/id/%s', $self->get_base_url, $package_name;

  my $ua  = LWP::UserAgent->new;
  my $req = HTTP::Request->new( GET => $package_url );
  my $rsp = $ua->request($req);

  die Dumper( [ rsp => $rsp ] )
    if !$rsp->is_success;

  my $package_zipped = $rsp->content;
  my $package        = q{};

  gunzip( \$package_zipped, \$package );

  my $tar = Archive::Tar->new;

  my $fh = IO::Scalar->new( \$package );

  $tar->read($fh);

  $self->set_package($tar);

  my ($package_basename) = $package_name =~ /^D\/DU\/DUMMY\/(.*?)[.]tar[.]gz$/xsm;

  $logger->debug(
    sub {
      return Dumper(
        [ package_basename => $package_basename,
          files            => $tar->list_files
        ]
      );
    }
  );

  return $self;
}

########################################################################
sub _create_module_index {
########################################################################
  my ($self) = @_;

  my $index = $self->get_darkpan_index;

  $index =~ s/^(?:.*)?\n\n//xsm;

  my @modules = split /\n/xsm, $index;
  my %module_index;
  my %module_versions;

  foreach (@modules) {
    my ( $module, $version, $zip ) = split /\s+/xsm;

    if ( $module_versions{$module} && $version gt $module_versions{$module} ) {
      delete $module_index{$zip};
    }

    $module_index{$zip} //= [];
    push @{ $module_index{$zip} }, $module;
  }

  $self->set_module_index( \%module_index );

  return $self;
}

########################################################################
sub init_logger {
########################################################################
  my ($self) = @_;

  my $level = $self->get_log_level // 'info';

  $level = {
    'trace' => $TRACE,
    'debug' => $DEBUG,
    'info'  => $INFO,
    'warn'  => $WARN,
    'error' => $ERROR,
    'trace' => $TRACE,
  }->{$level} // $INFO;

  Log::Log4perl->easy_init($level);

  $self->set_logger( Log::Log4perl->get_logger );

  return $self;
}

########################################################################
sub fetch_options {
########################################################################

  my %options = (
    'log-level' => 'info',
    'base-url'  => $BASE_URL,
  );

  my @option_specs = qw(
    help|h
    package|p=s
    module|m=s
    log-level|l=s
    base-url|u=s
  );

  my $retval = GetOptions( \%options, @option_specs );

  if ( !$retval || $options{help} ) {
    pod2usage( -exitval => 1, -verbose => 1 );
  }

  foreach my $o ( keys %options ) {
    next if $o !~ /[-]/xsm;

    my $value = delete $options{$o};
    $o =~ s/[-]/_/xsm;
    $options{$o} = $value;
  }

  return \%options;
}

########################################################################
sub main {
########################################################################

  my $options = fetch_options();

  my $self = DarkPAN::Utils->new($options);

  $self->init_logger;

  my $logger = $self->get_logger;

  $self->fetch_darkpan_index;

  $logger->trace(
    Dumper(
      [ packages     => [ sort keys %{ $self->get_module_index } ],
        module_index => $self->get_module_index,
      ]
    )
  );

  my $module = $self->get_module;

  if ($module) {
    my $package = $self->find_module($module);

    die sprintf "could not find %s\n", $module
      if !$package;

    $logger->info( sprintf 'fetching package: %s', $package );

    $self->fetch_package($package);

    my $file = $self->extract_module( $package, $module );

    my $docs = DarkPAN::Module::Docs->new($file);

    print {*STDOUT} $docs->{html};
  }

  return 0;
}

1;

