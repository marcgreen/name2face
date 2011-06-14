#!/usr/bin/perl

use warnings;
use 5.14.0;

use Data::Dumper;
use File::Find;
use File::Spec;
use GetOpt::Long;
use HTML::Element;
use HTML::TreeBuilder;
#use PDF::FromHTML;

# XXX Test section being 'name2face/Section1', etc.
#     What will the file be named? Do images still link properly?

# globals
my $File; # html file from which info is extracted
GetOptions(
    'html!' => \(my $Gen_html = 0),  # Don't generate .html by default
    'pdf!'  => \(my $Gen_pdf = 1),   # Generate .pdf by default
    'outfile=s' => \(my $Outfile),   # Name of generated pdf/html
                                     #   Default name is directory (arg) name
);

my @sections = @ARGV;
usage() unless @sections;


foreach my $dir (@sections) {
    usage() unless -d $dir;

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

    $html .= htmlify_students($dir, @students);
      # $dir is passed b/c it needs to be prepended to image sources
    $html .= <<"END_HTML";
</body>
</html>
END_HTML

    # Output html version
    my $htmlout = "$Output.html" or "$dir.html";
    open(my $fh, '>', $htmlout);
    print $fh $html;
    close $fh;

    # Convert html to pdf
    my $pdfout = "$Output.pdf" or "$dir.pdf";

    # Keep only files user specified
    unlink $htmlout unless $Gen_html;
    unlink $pdfout  unless $Gen_pdf;
}

#######

# Find html file
sub find_file {
    # make sure we have the right html file
    /\.html$/ or return;
    $File::Find::dir !~ /_files$/ or return; # ignore files in image dir
    # XXX - do I know it will always end in _files?
    # XXX - if there is more than 1 html file in the dir, the latter
    #       alphabetical one will be assigned to $File. Fix/warn for this?

    $File = $File::Find::name;
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
            # Processing student, get her major
            my ($major, $dept) = split(/, /, $major_dept->right->as_text);
            push @{$student{'majors'}}, $major;
            # Ignore $dept for now, I don't know what to do with it
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
    my $num_cols = 2; # 3 students per row
    my $num_rows = $#students % $num_cols ? int($#students / $num_cols)
                                          : $#students / $num_cols - 1;
    my $img_height = 100; # in px
    # XXX Make rows spread out more (horizontally and vertically)
    my $table = "<table>";
    for my $i (0..$num_rows) {
        $table .= "<tr>";
        for my $j (0..$num_cols) {
            my %s = %{shift @students} if @students;
            last unless %s; # did we run out?
            my $img_src = File::Spec->catdir($dir, $s{'img'});
            $table .= qq|<td><img src="$img_src" |.
                qq|alt="No Photo Available" height="${img_height}px"><br />|.
                "<b>$s{'name'}</b><br />";
            $table .= $#{$s{'majors'}} > 0 ? "Majors: " : "Major: ";
            $table .= join(', ', @{$s{'majors'}}) ."<br />";
            if ($s{'minors'}) { # student has minor(s)
                $table .= $#{$s{'minors'}} > 0 ? "Minors: " : "Minor: ";
                $table .= join(', ', @{$s{'minors'}}) ."<br />";
            }
            $table .= "Class: $s{'class'}</td>";
        }
        $table .= "</tr>";
    }
    $table .= "</table>";
}

sub usage {
    die <<'USAGE';

    This program generates a pdf file (and optionally an html file) containing
    a table of student's names and their pictures, among other small details.
    The purpose is to help professors put names to their student's faces. 

Usage: $0 --[no]html --out=<name> --[no]pdf -- section/

  --[no]html - generate an html file of the finished output (off by default).
  --out      - extensionless filename given to the generated files (default is
               the name of the directory being processed, i.e., the argument
               given to the program).
  --[no]pdf  - generate a pdf file of the finished output (on by default).

    The 'section/' to be processed ought to be a directory of a downloaded
    Faculty Class List, achieved by saving the bannerweb page as a
    'Web page, Complete' in a web browser. This means it should be a directory
    in which there is a single html file of the Faculty Class List and an
    accompanying directory that holds the student pictures.

USAGE
}
