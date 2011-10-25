#!/usr/bin/perl
# Marc Green

use warnings;
use strict;
#use 5.14.0;

use Data::Dumper;
use File::Basename;
use File::Find;
use File::Spec;
use Getopt::Long;
use HTML::Element;
use HTML::TreeBuilder;
use HTML::HTMLDoc;

# XXX Add option to use absolute links, or relative links from a different directory
# XXX Expanding on that, user should be able to use --out to specify a different
#     relative directory per section, and perhaps a --prefix option for all Sections

# globals
my $File; # html file from which info is extracted
GetOptions(
    'html!' => \(my $Gen_html = 0),  # Don't generate .html by default
    'pdf!'  => \(my $Gen_pdf = 1),   # Generate .pdf by default
    'out=s@' => \(my $Outfile),      # Name of generated pdf/html
                                     #   Default name is directory (arg) name
#    'cols=i' => \(my $Num_cols = 3), # 3 columns of students by default
#    'rows=i' => \(my $Num_rows = 4), # 4 rows of students per page by default
);
my $Num_cols = 3; # I removed --cols and --rows options for now, so I added
my $Num_rows = 4; # these globals

my @sections = @ARGV;
usage() unless @sections;

my $index = 0; # used in $outfie
for my $dir (@sections) {
    usage() unless -d $dir;

    $dir = File::Spec->catdir($dir); # remove trailing /
    find(\&find_file, $dir); # Finds html file, puts name into $File
    my $curfile = $File;

    # Extracts course info and student corpus from file
    my ($course_info, @students) = parse_file($curfile);

    # Format html with given course info and student list
    my $html = <<"BEGIN_HTML";
<html>
<head><title>$course_info->{'name'} STUDENT LIST</title></head>
<body>
<p>
$course_info->{'name'}<br />
CRN: $course_info->{'crn'}<br />
$course_info->{'duration'}
</p>
BEGIN_HTML

    $html .= htmlify_students(basename($dir), @students);
      # $dir is passed b/c it needs to be prepended to image sources
      # we remove any prior dirs than what is needed to make links relative
    $html .= <<"END_HTML";
</body>
</html>
END_HTML

    # Output html version
    if ($Gen_html) {
        my $htmlout = exists $Outfile->[$index] ? "$Outfile->[$index].html"
                                                : "$dir.html";
        open(my $fh, '>', $htmlout);
        print $fh $html;
        close $fh;
    }

    # Output pdf version
    if ($Gen_pdf) {
        my $pdfout = exists $Outfile->[$index] ? "$Outfile->[$index].pdf"
                                               : "$dir.pdf";
        my $htmldoc = new HTML::HTMLDoc();
        $htmldoc->set_html_content($html);
        $htmldoc->set_page_size('letter');
        $htmldoc->set_left_margin(1/4,'in');
        $htmldoc->set_right_margin(1/4,'in');
        $htmldoc->set_top_margin(1/4,'in');
        $htmldoc->set_bottom_margin(1/4,'in');
        $htmldoc->path(dirname($dir)); # to tell it where to find images
        my $pdf = $htmldoc->generate_pdf();
        $pdf->to_file($pdfout);
    }
    $index++;
}

#######

# Find html file
sub find_file {
    $File = $File::Find::name if /FacClaList\.html$/; # find the right html file
}

# Extract course info and student corpus from html file
sub parse_file {
    my $tree = HTML::TreeBuilder->new;
    $tree->parse_file(shift);
    $tree->elementify();

    # Course name, CRN, Duration
    my $course_info = format_course_info(
        $tree->look_down(
            _tag  => "table",
            class => "datadisplaytable",
            sub { $_[0]->look_down(
                      _tag => "caption", # find <caption> in <table>
                      sub { $_[0]->as_text() eq 'Course Information' }
                      )
            }
        )
    );

    my @students = format_students(
        $tree->look_down(
            _tag  => "table",
            class => "datadisplaytable",
            sub { $_[0]->look_down(
                      _tag => "caption", # find <caption> in <table>
                      sub { $_[0]->as_text() eq 'Detail Class List' }
                      )
            }
        )
    );

    $tree->delete;
    return ($course_info, @students);
}

# Format table of course information into hash
sub format_course_info {
    my $table = shift;
    my $tbody = ($table->content_list())[1]; # 0th is caption, 1st is tbody
    my ($name, $crn, $duration) = map { $_->as_text } $tbody->content_list;
    my %course;
    $course{'name'}     = ($name                      or 'N/A');
    $course{'crn'}      = ((split(':', $crn))[1]      or 'N/A');
      # format: "CRN:######" - we want the ###### part
    $course{'duration'} = ((split(':', $duration))[1] or 'N/A');
    return \%course;
}

# Format table of students into array of hashrefs
sub format_students {
    my $table = shift;
    my $tbody = ($table->content_list())[1];

    # Each student's info is placed one after another in a series of <tr>s so
    # there is no easy way to divide the students up.
    my (@students, %student);
    for my $tr ($tbody->content_list()) {
        if ((my $img = $tr->look_down("_tag" => "img",
                                      "alt" => qr/No Photo Available/)) &&
            (my $name = $tr->look_down("_tag" => "a",
                                       "href" => qr/admin\.wpi\.edu/))) {
            # Starting a new student, add old one to running list
            push @students, {%student} if keys %student;
            undef %student; # Get rid of old student's information
            # grab new student's name and their photo
            $student{'name'} = $name->as_text;
            $student{'img'} = $img->attr('src');
        } elsif (my $major = $tr->look_down(
                     "_tag" => "th",
                     sub { $_[0]->as_text eq 'Major:' } )) {
            # Processing student, get her major
            push @{$student{'majors'}}, $major->right->as_text
              # allow for multiple majors
        } elsif (my $major_dept = $tr->look_down(
                     "_tag" => "th",
                     sub { $_[0]->as_text eq 'Major and Department:' } )) {
            # Processing student, get her major and department
            my ($major, $dept) = split(/, /, $major_dept->right->as_text);
            push @{$student{'majors'}}, $major;
            $student{'dept'} = $dept;
        } elsif (my $minor = $tr->look_down(
                     "_tag" => "th",
                     sub { $_[0]->as_text eq 'Minor:' } )) {
            # Processing student, get her minor
            push @{$student{'minors'}}, $minor->right->as_text
        } elsif (my $class = $tr->look_down(
                     "_tag" => "th",
                     sub { $_[0]->as_text eq 'Class:' } )) {
            # Processing student, get her class
            $student{'class'} = $class->right->as_text
        }
    }

    push @students, {%student} if keys %student; # push final student

    return @students;
}

sub htmlify_students {
    my ($dir, @students) = @_;
    my $cell_space = 20; # space between table cells
    my $num_cols = $Num_cols; # 3 students per row by default
    my $tot_rows = $#students % $num_cols ? int($#students / $num_cols)
                                          : $#students / $num_cols - 1;
    my $img_h = 100; # height in px
    my $table = "<table cellspacing='$cell_space'>";
    for my $i (1..$tot_rows) {
        $table .= "<tr>";
        for my $j (1..$num_cols) {
            my %s = %{shift @students} if @students;
            last unless %s; # did we run out?
            my $img_src = File::Spec->catdir($dir, $s{'img'});
            $table .= qq|<td><img src="$img_src" |.
                qq|alt="No Photo Available" height="${img_h}"> <br />|.
                qq|<b>$s{'name'}</b><br />|;
            $table .= $#{$s{'majors'}} > 0 ? "Majors: " : "Major: ";
            # XXX student's majors are all on one line, could push rest of page
            $table .= join(', ', @{$s{'majors'}}) ."<br />";
            if ($s{'minors'}) { # student has minor(s)
                $table .= $#{$s{'minors'}} > 0 ? "Minors: " : "Minor: ";
                $table .= join(', ', @{$s{'minors'}}) ."<br />";
            }
            $table .= "Dept: $s{'dept'}<br />" if $s{'dept'};
            $table .= "Class: $s{'class'}";
            $table .= "</td>";
        }
        $table .= "</tr>";
        # Let HTML::HTMLDoc know we want a page break every $Num_rows
        $table .= "<!-- PAGE BREAK -->" unless $i % ($Num_rows);
    }
    $table .= "</table>";
}

sub usage {
    die <<"USAGE";

    This program generates a pdf file (and optionally an html file) containing
    a table of student's names and their pictures, among other small details.
    The purpose is to help professors put names to their student's faces.

Usage: perl $0 [options] -- [sections to process]
E.g., perl $0 --html --out classlist1 --out "class list 2"
                        -- Section1/ Section2/

Options
  --[no]html   generate an html file of the finished output (off by default).
  --out <name> extensionless filename given to the generated files (default is
               the name of the directory being processed, i.e., the argument
               given to the program). You can pass multiple --out=<name> options
               and the nth one will be applied to the nth section.
  --[no]pdf    generate a pdf file of the finished output (on by default).

    The 'section/' to be processed ought to be a directory of a downloaded
    Faculty Class List, achieved by saving the bannerweb page as a
    'Web page, Complete' in a web browser. This means it should be a directory
    in which there is a single html file of the Faculty Class List and an
    accompanying directory that holds the student pictures.

USAGE
}
