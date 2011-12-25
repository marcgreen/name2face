package Name2Face::Base;
# Marc Green

use warnings;
use 5.14.0;

require Exporter;
our @EXPORT = qw/name2face/;
our $VERSION = 1;

use Data::Dumper;
use File::Basename;
use File::Find;
use File::Spec;
use HTML::Element;
use HTML::TreeBuilder;
use HTML::HTMLDoc;

# XXX Add option to use absolute links, or relative links from a different directory
# XXX Expanding on that, user should be able to use --out to specify a different
#     relative directory per section, and perhaps a --prefix option for all Sections

# globals
my $File; # used in file::find's callback as the html file we parse

# usage: my $n2f = Name2Face::Base->new(output_html => 0, output_pdf => 1);
# or leave out the key for the default value
sub new {
    my $class = shift;
    my %args = @_;
    return bless {
        output_html => ($args{'output_html'} // 0),
        output_pdf  => ($args{'output_pdf'} // 1),
        num_rows    => 4,
        num_cols    => 3,
    }, $class;
}

# usage: $n2f->name2face('path to section1' => 'name of section1 pdf', ...);
sub name2face {
    my $self = shift;
    my %sections = @_;

    while (my ($path, $name) = each %sections) {
        unless (-d $path) {
            warn "$path not a directory, skipping";
            next;
        }

        $path = File::Spec->catdir($path); # remove trailing /
        find(\&find_file, $path); # Finds html file, puts name into $File
        my $curfile = $File;

        # Extracts course info and student corpus from file
        my ($course_info, @students) = $self->parse_file($curfile);

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

        $html .= $self->htmlify_students(basename($path), @students);
        # $path is passed b/c it needs to be prepended to image sources
        # we remove any prior dirs than what is needed to make links relative
        $html .= <<"END_HTML";
</body>
</html>
END_HTML

        # Output html version
        if ($self->{'output_html'}) {
            open(my $fh, '>', "$name.html");
            print $fh $html;
            close $fh;
            warn "something went wrong with $name.html" unless -e "$name.html";
        }

        # Output pdf version
        if ($self->{'output_pdf'}) {
            my $htmldoc = new HTML::HTMLDoc();
            $htmldoc->set_html_content($html);
            $htmldoc->set_page_size('letter');
            $htmldoc->set_left_margin(1/4,'in');
            $htmldoc->set_right_margin(1/4,'in');
            $htmldoc->set_top_margin(1/4,'in');
            $htmldoc->set_bottom_margin(1/4,'in');
            $htmldoc->path(dirname($path)); # to tell it where to find images
            my $pdf = $htmldoc->generate_pdf();
            $pdf->to_file("$name.pdf");
            warn "something went wrong with $name.pdf" unless -e "$name.pdf";
        }
    }
}

# Find html file
sub find_file {
    $File = $File::Find::name if /FacClaList\.html$/; # find the right html file
}

# Extract course info and student corpus from html file
sub parse_file {
    my $self = shift;
    my $tree = HTML::TreeBuilder->new;
    $tree->parse_file(shift);
    $tree->elementify();

    # Course name, CRN, Duration
    my $course_info = $self->format_course_info(
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

    my @students = $self->format_students(
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
    my $self = shift;
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
    my $self = shift;
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
    my $self = shift;
    my ($dir, @students) = @_;
    my $cell_space = 20; # space between table cells
    my $num_cols = $self->{'num_cols'}; # 3 students per row by default
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
        $table .= "<!-- PAGE BREAK -->" unless $i % ($self->{'num_rows'});
    }
    $table .= "</table>";
}

1;
