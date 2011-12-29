#Marc Green
package Name2Face::Gui::Frame;
use base "Wx::Frame";

use warnings;
use 5.14.0;
use Data::Dumper;
use Wx qw/:everything/;
use Wx::Event qw/EVT_BUTTON/;

sub new {
    my $ref = shift;
    my $self = $ref->SUPER::new(
        undef,           # parent window
        -1,              # ID -1 means any
        'Name2Face',     # title
        wxDefaultPosition,
        [700,400],
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

    # left side of the instructions
    my $l_instr_panel = Wx::Panel->new($self);
    my $instr1 = Wx::StaticText->new(
        $l_instr_panel,     # Parent window
        -1,         # no window ID
        'Add as many sections as you want, they will appear in fields below:',
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

    $self->{'sizer'}->Add($introH, 0, wxEXPAND | wxLEFT | wxTOP | wxRIGHT, 20);

    EVT_BUTTON($self, $addSectionBtn, \&OnAddSection);
    EVT_BUTTON($self, $genPDFBtn, \&OnGenPDF);
}

sub addSectionLine {
    my ($self, $path) = @_;
    my $sizer = $self->{'sizer'};

    # show the header since we are adding sections
    $self->{'sectionSizer'}->Show(0,1);
    $self->{'sectionSizer'}->Show(1,1);
    $self->{'sectionSizer'}->Show(2,1);

    # XXX should these be in panels?
    my $p = Wx::TextCtrl->new(
        $self,
        -1,
        $path,);
    my $n = Wx::TextCtrl->new(
        $self,
        -1,
        "$path.pdf",);
    my $del = Wx::Button->new(    # XXX replace text with icon bmp
        $self,
        -1,
        'Delete',);

    $self->{'sectionSizer'}->Add($p, 1, wxEXPAND);
    $self->{'sectionSizer'}->Add($n, 1, wxEXPAND);
    $self->{'sectionSizer'}->Add($del, 0);

    $sizer->Layout;

    EVT_BUTTON($self, $del, \&OnDelSection);

    push @{$self->{'lines'}}, [$p, $n, $del]; # so we can delete it if necessary
    push @{$self->{'paths'}}, $path;
}

sub addHeader {
    my $self = shift;
    my $sizer = $self->{'sizer'};

    $self->{'sectionSizer'} = Wx::FlexGridSizer->new(0,3,2,5);
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
        'Name of generated file',);

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

sub OnDelSection {
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

sub OnAddSection {
    my($self, $event) = @_;
    my $dlg = Wx::DirDialog->new($self, "Choose a Section");
    if ($dlg->ShowModal == wxID_OK) {
        say $dlg->GetPath();
        $self->addSectionLine($dlg->GetPath()); # Show the user
    }
    $dlg->Destroy;
}

sub onGenPDF {

}

1;

