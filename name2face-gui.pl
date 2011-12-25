#!/usr/bin/perl
# Marc Green

use lib 'lib';
use warnings;
use 5.14.0;
use Name2Face::Gui::App;

my $n2f = Name2Face::Gui::App->new;
$n2f->MainLoop;
