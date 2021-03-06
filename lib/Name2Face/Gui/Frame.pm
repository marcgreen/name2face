#Marc Green
package Name2Face::Gui::Frame;
use base "Wx::Frame";

use warnings;
use 5.14.0;
use Data::Dumper;
use Wx qw/:everything/;
use Wx::Event qw/EVT_BUTTON/;

use Name2Face::Base;

# XXX TODO
# -- add scrollbar if there are more sections than window space
# -- warn/prompt if overwriting a file
# -- use global $width and $height to calculate initial Wraps and sizes
# -- replace "Delete" text with a bitmap of a white X on red background

my ($width, $height) = (800, 600);

sub new {
    my $ref = shift;
    my $self = $ref->SUPER::new(
        undef,           # parent window
        -1,              # ID -1 means any
        'Name2Face',     # title
        wxDefaultPosition,
        [$width, $height],
        );

    $self->{'sizer'} = Wx::BoxSizer->new(wxVERTICAL); # top level sizer
    $self->addInstructions(); # display instructions/buttons for the user
    $self->addHeader(); # create the header (but keep it hidden for now)
    $self->SetSizer($self->{'sizer'});
    return $self;
}

sub addInstructions() {
    my $self = shift;

    my $introH = Wx::BoxSizer->new(wxHORIZONTAL);

    # description of program
    my $desc_panel = Wx::Panel->new($self);
    my $desc = Wx::StaticText->new(
        $desc_panel,
        -1,
        <<DESC,
This program generates a pdf file containing a table of student's names and their pictures, among other small details. The purpose is to help professors put names to their student's faces.

Each section to be processed ought to be a directory of a downloaded Faculty Class List, achieved by saving the bannerweb page as a 'Web page, Complete' in a web browser. This means it should be a directory in which there is a single html file of the Faculty Class List and an accompanying directory that holds the student pictures.
DESC
        );
    $desc->Wrap($width-40); # -40 for padding on each side
    $self->{'sizer'}->Add($desc_panel, 0, wxEXPAND|wxLEFT|wxTOP|wxRIGHT, 20);

    # left side of the instructions
    my $l_instr_panel = Wx::Panel->new($self);
    my $instr1 = Wx::StaticText->new(
        $l_instr_panel,     # Parent window
        -1,         # no window ID
        'Add as many sections as you want, they will appear in fields below:'
        );
    $instr1->Wrap(250);
    my $addSectionBtn = Wx::Button->new(
        $l_instr_panel,
        -1,
        'Add a Section',
        [0, 40]
        );

    # right side of the instructions
    my $r_instr_panel = Wx::Panel->new($self);
    my $instr2 = Wx::StaticText->new(
        $r_instr_panel,
        -1,
        'When you are done adding sections, generate the PDF files:',
        );
    $instr2->Wrap(250);
    my $genPDFBtn = Wx::Button->new(
        $r_instr_panel,
        -1,
        'Generate PDFs',
        [0, 40]
        );

    $introH->Add($l_instr_panel, 0);
    $introH->AddStretchSpacer(1);
    $introH->Add($r_instr_panel, 0);

    $self->{'sizer'}->Add($introH, 0, wxEXPAND|wxLEFT|wxTOP|wxRIGHT, 20);

    EVT_BUTTON($self, $addSectionBtn, \&onAddSection);
    EVT_BUTTON($self, $genPDFBtn, \&onGenPDF);
}

sub addHeader {
    my $self = shift;
    my $sizer = $self->{'sizer'};

    $self->{'sectionSizer'} = Wx::FlexGridSizer->new(
        0, # number of rows (0 means dynamically determined)
        3, # number of columns
        2, # space between rows
        5); # space between columns
    $self->{'sectionSizer'}->AddGrowableCol(0, 1); # expand columns 1
    $self->{'sectionSizer'}->AddGrowableCol(1, 1); # and 2
    my $l_head_panel = Wx::Panel->new($self);
    my $head1 = Wx::StaticText->new(
        $l_head_panel,
        -1,
        'Path to Section',);
    my $r_head_panel = Wx::Panel->new($self);
    my $head2 = Wx::StaticText->new(
        $r_head_panel,
        -1,
        'Name of generated file (without file extension)',);

    $self->{'sectionSizer'}->Add($l_head_panel, 1);
    $self->{'sectionSizer'}->Add($r_head_panel, 1);
    $self->{'sectionSizer'}->AddSpacer(1); # for 3rd column
    $sizer->Add($self->{'sectionSizer'}, 0, wxEXPAND | wxALL, 40);

    # hide it until a section is added
    $self->{'sectionSizer'}->Hide(0); # 3 elements in the header
    $self->{'sectionSizer'}->Hide(1);
    $self->{'sectionSizer'}->Hide(2);
    $self->{'sectionSizer'}->Layout;
}

sub addSectionLine {
    my ($self, $path) = @_;
    my $sizer = $self->{'sizer'};

    # show the header since we are adding sections
    $self->{'sectionSizer'}->Show(0,1);
    $self->{'sectionSizer'}->Show(1,1);
    $self->{'sectionSizer'}->Show(2,1);

    # XXX should these be in panels?
    # (then they won't wxEXPAND?)
    my $p = Wx::TextCtrl->new(
        $self,
        -1,
        $path,);
    my $n = Wx::TextCtrl->new(
        $self,
        -1,
        $path,);
    my $del = Wx::Button->new(    # XXX replace text with icon bmp
        $self,
        -1,
        'Delete',);

    $self->{'sectionSizer'}->Add($p, 1, wxEXPAND);
    $self->{'sectionSizer'}->Add($n, 1, wxEXPAND);
    $self->{'sectionSizer'}->Add($del, 0);

    $sizer->Layout;

    EVT_BUTTON($self, $del, \&onDelSection);

    # keep track of each line so we can retrieve path/name or delete it
    push @{$self->{'lines'}}, [$p, $n, $del];
}

sub onDelSection {
    my ($self, $event) = @_;

    # find the delete button that triggered this deletion
    # and remove the line
    my $index = 0;
    for my $line (@{$self->{'lines'}}) {
        if ($line->[2]->GetId == $event->GetId) {
            # detach line from sizer and then delete it
            $self->{'sectionSizer'}->Detach($_) for @$line;
            $_->Destroy for @$line;
            last;
        }
        $index++;
    }

    # remove the line from our list
    splice(@{$self->{'lines'}}, $index, 1);

    # if there are no lines left, hide the header
    if ($#{$self->{'lines'}} == -1) {
        $self->{'sectionSizer'}->Hide(0);
        $self->{'sectionSizer'}->Hide(1);
        $self->{'sectionSizer'}->Hide(2); 
    }

    $self->{'sectionSizer'}->Layout;
}

sub onAddSection {
    my($self, $event) = @_;
    my $dlg = Wx::DirDialog->new($self, "Choose a Section");
    if ($dlg->ShowModal == wxID_OK) {
        #say $dlg->GetPath();
        $self->addSectionLine($dlg->GetPath()); # Display/bookkeep section
    }
    $dlg->Destroy;
}

sub onGenPDF {
    my ($self, $event) = @_;
    my $n2f = Name2Face::Base->new();
    return unless $self->{'lines'};

    my $num_files = scalar @{$self->{'lines'}};

    my $progress = Wx::ProgressDialog->new(
        'Generate PDFs',
        '',
        $num_files,
        $self,
        wxPD_AUTO_HIDE|wxPD_APP_MODAL|wxPD_ELAPSED_TIME
        );

    my $cur_file = 0;
    for my $line (@{$self->{'lines'}}) {
        my ($path, $name) = map { $_->GetValue } ($line->[0], $line->[1]);
        $progress->Update($cur_file++, "File $cur_file of $num_files");
        # path to section => name of output file
        $n2f->name2face($path, $name);
    }

    $progress->Destroy;  
}

1;

