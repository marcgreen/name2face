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
    my $self = $ref->SUPER::new(undef,           # parent window
                                -1,              # ID -1 means any
                                'Name2Face',     # title
                                [-1,-1],
                                [600,400],
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

    $self->{'sectionY'} = 110; # at what Y value the section lines will start
    $self->{'sectionYInc'} = 35; # how much to increment the Y value each time

    EVT_BUTTON($self, $dirDialog, \&OnDirDialog);

    return $self;
}

sub addSectionLine {
    my $self = shift;
    my $path = shift;

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
                              'Delete Section',
                              [540,$self->{'sectionY'}],
        );

    EVT_BUTTON($self, $del, \&OnDelSection);

    push @{$self->{'lines'}}, [$p, $n, $del]; # so we can delete it if necessary
    push @{$self->{'paths'}}, $path;
    $self->{'sectionY'} += $self->{'sectionYInc'};
}

sub OnDelSection {
    my ($self, $event) = @_;

    # find the delete button that triggered this deletion
    my ($index, $line);
    while (($index, $line) = each @{$self->{'lines'}}) {
        last if $line->[2]->GetId == $event->GetId;
    }

    # LEFT OFF trying to get this to work properly

    # remove all entries after the deleted line, inclusive
    my @paths = splice(@{$self->{'paths'}}, $index);
    my @lines = splice(@{$self->{'lines'}}, $index);
    for my $line (@lines) {
        $_->Destroy for @$line; # delete all widgets in the line
    }

    say Dumper(\@paths);

    # redraw them one line higher, (not including the deleted line, of course)
    if (shift @paths) { # remove deleted line from @paths
        $self->{'sectionY'} -= length(@paths)*$self->{'sectionYInc'}; # reset y position
        $self->addSectionLine($_) for @paths;
    }
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

