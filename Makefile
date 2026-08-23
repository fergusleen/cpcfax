.PHONY: build dsk dsk-amsnet amsnet clean

build:
	bash tools/build.sh

dsk: build
	bash tools/make_dsk.sh

dsk-amsnet:
	bash tools/make_amsnet_dsk.sh

amsnet: dsk-amsnet

clean:
	rm -rf build dist
