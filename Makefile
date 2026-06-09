DC ?= ldc2

# Smart fallback: if ldc2 is missing, check for DMD
ifeq (, $(shell command -v $(DC) 2>nul || where $(DC) 2>nul))
    ifneq (, $(wildcard C:/D/dmd2/windows/bin/dmd.exe))
        DC := C:/D/dmd2/windows/bin/dmd.exe
    else ifneq (, $(shell command -v dmd 2>nul || where dmd 2>nul))
        DC := dmd
    else ifneq (, $(shell command -v gdc 2>nul || where gdc 2>nul))
        DC := gdc
    endif
endif

EXE = $(if $(OS),.exe,)

ifeq ($(findstring gdc,$(DC)),gdc)
    OUT_FLAG = -o bin/merlin$(EXE)
else
    OUT_FLAG = -of=bin/merlin$(EXE)
endif

.PHONY: all clean install

all: bin/merlin$(EXE)

bin/merlin$(EXE): $(wildcard src/*.d) | bin
	@echo "Building standalone Merlin Engine with $(DC)..."
	$(DC) $(wildcard src/*.d) $(OUT_FLAG)

bin:
	-@mkdir bin 2>nul || cd .

clean:
	-@rm -rf bin obj 2>nul || cd .

install: bin/merlin$(EXE)
	@echo "Installing merlin..."
	@cp bin/merlin$(EXE) /usr/local/bin/merlin$(EXE) || echo "Please add merlin to your PATH manually or copy it"
