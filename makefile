all: name2face name2face-gui

name2face: name2face.pl lib/Name2Face/Base.pm
	pp -o name2face -I lib name2face.pl

name2face-gui: name2face-gui.pl lib/Name2Face/Base.pm lib/Name2Face/Gui/Frame.pm lib/Name2Face/Gui/App.pm
	pp --gui -o name2face-gui -I lib name2face-gui.pl

tar: name2face.pl lib/Name2Face/Base.pm
	tar czf n2f.tar.gz name2face.pl makefile lib Section1 Section2 Section3 IMGD4000

clean:
	rm name2face name2face-gui *.pdf