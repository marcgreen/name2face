#!/usr/bin/perl
# Marc Green

use warnings;
use 5.14.0;

use File::Spec;
use Getopt::Long;
use Name2Face::Base;

# put htmldoc in user's path
$ENV{'PATH'} .= ':/home/marcgreen/htmldoc/bin' if $ENV{'PATH'} !~ /htmldoc/;

GetOptions(
    'html!'  => \(my $Gen_html = 0),# Don't generate .html by default
    'pdf!'   => \(my $Gen_pdf = 1), # Generate .pdf by default
);

my @sections = @ARGV;
usage() unless @sections;

my %sects;
for (@sections) {
    my $dir = File::Spec->catdir($_); # remove trailing / for naming purposes
    $sects{$dir} = $dir;
}

my $n2f = Name2Face::Base->new(output_html => $Gen_html, output_pdf => $Gen_pdf);
# %sects is given as a hash to allow the user to supply a different filename
# than the name of the directory. This feature has been removed for now
$n2f->name2face(%sects);

sub usage {
    die <<"USAGE";

    This program generates a pdf file (and optionally an html file) containing
    a table of student's names and their pictures, among other small details.
    The purpose is to help professors put names to their student's faces.

Usage: /home/marcgreen/n2f/name2face [options] -- [sections to process]
E.g.,  /home/marcgreen/n2f/name2face --html Section1/ Section2/

Options
  --[no]html   generate an html file of the finished output (off by default).
  --[no]pdf    generate a pdf file of the finished output (on by default).

    The "section" to be processed ought to be a directory of a downloaded
    Faculty Class List, achieved by saving the bannerweb page as a
    'Web page, Complete' in a web browser. This means it should be a directory
    in which there is a single html file of the Faculty Class List and an
    accompanying directory that holds the student pictures. 

USAGE
}
