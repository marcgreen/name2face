all: name2face name2face-gui

name2face: name2face.pl
	pp -o name2face -I lib name2face.pl

name2face-gui: name2face-gui.pl
	pp --gui -o name2face-gui -I lib name2face-gui.pl

name2face.pl: lib/Name2Face/Base.pm

name2face-gui.pl: lib/Name2Face/Base.pm lib/Name2Face/Gui/Frame.pm lib/Name2Face/Gui/App.pm
