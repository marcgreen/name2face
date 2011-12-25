# Marc Green

use Wx;
use warnings;
use 5.14.0;

package Name2Face::Gui::App;
use base "Wx::App";
use Name2Face::Gui::Frame;

sub OnInit {
    my $frame = Name2Face::Gui::Frame->new();
    $frame->Show(1);
}

1;
