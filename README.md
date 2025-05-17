# NAME

DarkPAN::Utils - set of utilities for working with a DarkPAN

# SYNOPSIS

    use DarkPAN::Utils qw(parse_distribution_path);

    use DarkPAN::Utils::Docs;

    my $dpu = DarkPAN::Utils->new(
      log_level => 'debug',
      base_url  => 'https://cpan.openbedrock.net/orepan2',
    );

    $dpu->fetch_darkpan_index;

    my $package = $dpu->find_module('SomeApp::Module');


    if ($package) {
      $dpu->fetch_package( $package->[0] );
    }


    my $file = $dpu->extract_module( $package->[0], 'SomeApp::Module');
    my $docs = DarkPAN::Utils::Docs->new( text => $file );

    $docs->parse_pod;

    print $docs->get_html();

# DESCRIPTION

# METHODS AND SUBROUTINES

## new

## parse\_distribution\_path

## find\_module

## extract\_file

## extract\_module

## fetch\_darkpan\_index

## fetch\_package

## init\_logger

## fetch\_options

# AUTHOR

Rob Lauer - <rlauer6@comcast.net>

# SEE ALSO

[OrePAN2](https://metacpan.org/pod/OrePAN2), [OrePAN2::S3](https://metacpan.org/pod/OrePAN2%3A%3AS3)
