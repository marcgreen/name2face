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

    my $outerV = Wx::BoxSizer->new(wxVERTICAL);
    my $introH = Wx::BoxSizer->new(wxHORIZONTAL);
    my $headingH = Wx::BoxSizer->new(wxHORIZONTAL);

    # left side of the instructions
    my $l_instr_panel = Wx::Panel->new($self, -1, [-1, -1], [300, 100]);
    my $instr1 = Wx::StaticText->new(
        $l_instr_panel,     # Parent window
        -1,         # no window ID
        'Add as many sections as you want, they will appear in fields below:',
        );
    $instr1->Wrap(300);
    my $addSectionBtn = Wx::Button->new(
        $l_instr_panel,
        -1,
        'Add a Section',
        [0, 40]
        );

    # right side of the instructions
    my $r_instr_panel = Wx::Panel->new($self, -1, [-1, -1], [300, 100]);
    my $instr2 = Wx::StaticText->new(
        $r_instr_panel,
        -1,
        'When you are done adding sections, generate the PDF files:',
        );
    $instr2->Wrap(300);
    my $genPDFBtn = Wx::Button->new(
        $r_instr_panel,
        -1,
        'Generate PDFs',
        [0, 40]
        );

    $introH->Add($l_instr_panel, 0, wxALL, 20);
    $introH->AddStretchSpacer(1);
    $introH->Add($r_instr_panel, 0, wxALL, 20);

    # XXX why do the spacers overlap?

    # heading for sections
    my $l_head_panel = Wx::Panel->new($self, -1, [-1, -1], [100, 20]);
    my $head1 = Wx::StaticText->new(
        $l_head_panel,
        -1,
        'Path to Section',);
    my $r_head_panel = Wx::Panel->new($self, -1, [-1, -1], [100, 20]);
    my $head2 = Wx::StaticText->new(
        $r_head_panel,
        -1,
        'Name of generated file(s)',);

    $headingH->Add($l_head_panel, 0, wxALL, 20);
    $headingH->AddStretchSpacer(1);
    $headingH->Add($r_head_panel, 0, wxALL, 20);


    $self->{'sectionYInc'} = 35; # how much to increment the Y value each time
    $self->{'sectionY'} = 110-$self->{'sectionYInc'};
      # at what Y value the section lines will start

    $outerV->Add($introH);
#    $outerV->Add($headingH);

    EVT_BUTTON($self, $addSectionBtn, \&OnAddSection);
#    EVT_BUTTON($self, $genPDFBtn, \&OnGenPDF);

    $self->SetSizer($outerV);
    return $self;
}

sub addSectionLine {
    my $self = shift;
    my $path = shift;
    $self->{'sectionY'} += $self->{'sectionYInc'};

    # path
    my $p = Wx::TextCtrl->new($self,
                      -1,
                      $path,
                      [20,$self->{'sectionY'}],
                      [350,30],
        );

    # name
    my $n = Wx::TextCtrl->new($self,
                      -1,
                      "$path.pdf",
                      [380,$self->{'sectionY'}],
                      [250,30],
        );

    # delete
    # XXX add icon bmp
    my $del = Wx::Button->new($self,
                              -1,
                              'Delete',
                              [640,$self->{'sectionY'}],
        );

    EVT_BUTTON($self, $del, \&OnDelSection);

    push @{$self->{'lines'}}, [$p, $n, $del]; # so we can delete it if necessary
    push @{$self->{'paths'}}, $path;
}

sub OnDelSection {
    my ($self, $event) = @_;
    my $p = $self->{'paths'};
    my $l = $self->{'lines'};

    # find the delete button that triggered this deletion
    my $index;
    for ($index = 0; $index < $#$l; $index++) {
        last if $$l[$index]->[2]->GetId == $event->GetId;
    }

    # remove all entries after the deleted line, inclusive
    my @paths = splice(@$p, $index);
    my @lines = splice(@$l, $index);
    for my $line (@lines) {
        $_->Destroy for @$line; # delete all widgets in the line
    }

    # redraw them one line higher, (not including the deleted line, of course)
    $self->{'sectionY'} -= $self->{'sectionYInc'} for @paths; # reset y position
    shift @paths; # remove deleted line from @paths
    $self->addSectionLine($_) for @paths;
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

