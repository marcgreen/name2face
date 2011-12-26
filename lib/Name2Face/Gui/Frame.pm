#Marc Green
package Name2Face::Gui::Frame;
use base "Wx::Frame";

use warnings;
use 5.14.0;
use Data::Dumper;
use Wx qw/:id/;
use Wx::Event qw/EVT_BUTTON/;

sub new {
    my $ref = shift;
    my $self = $ref->SUPER::new(
        undef,           # parent window
        -1,              # ID -1 means any
        'Name2Face',     # title
        [-1,-1],
        [650,400],
        );

    $self->{'panel'} = Wx::Panel->new($self);

    my $header = Wx::StaticText->new(
        $self->{'panel'},     # Parent window
        -1,         # no window ID
        'Add as many sections as you want, they will appear in fields below:',
        [20, 20],
        );
    #$header->Wrap(550); # wrap at col550

    my $dirDialog = Wx::Button->new($self->{'panel'},
                                    -1,
                                    'Add a Section',
                                    [20,45],
        );

    Wx::StaticText->new($self->{'panel'},
                        -1,
                        'Path to Section',
                        [20, 90],
        );

    Wx::StaticText->new($self->{'panel'},
                        -1,
                        'Name of generated file(s)',
                        [330, 90],
        );

    $self->{'sectionYInc'} = 35; # how much to increment the Y value each time
    $self->{'sectionY'} = 110-$self->{'sectionYInc'};
      # at what Y value the section lines will start

    EVT_BUTTON($self, $dirDialog, \&OnDirDialog);

    return $self;
}

sub addSectionLine {
    my $self = shift;
    my $path = shift;
    $self->{'sectionY'} += $self->{'sectionYInc'};

    # path
    my $p = Wx::TextCtrl->new($self->{'panel'},
                      -1,
                      $path,
                      [20,$self->{'sectionY'}],
                      [300,30],
        );

    # name
    my $n = Wx::TextCtrl->new($self->{'panel'},
                      -1,
                      $path, # need to basename() this (but do it w/ a Name2Face function)
                      [330,$self->{'sectionY'}],
                      [200,30],
        );

    # delete
    # XXX add icon bmp
    my $del = Wx::Button->new($self->{'panel'},
                              -1,
                              'Delete',
                              [540,$self->{'sectionY'}],
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

sub OnDirDialog {
    my($self, $event) = @_;
    my $dlg = Wx::DirDialog->new($self, "Choose a Section");
    if ($dlg->ShowModal == wxID_OK) {
        say $dlg->GetPath();
        $self->addSectionLine($dlg->GetPath()); # Show the user
    }
    $dlg->Destroy;
}

1;

