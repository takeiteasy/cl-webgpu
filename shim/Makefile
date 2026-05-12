# Makefile for webgpu_shim - C shim layer for Common Lisp FFI
#
# This Makefile can also build wgpu-native from ../deps/wgpu-native.

# Detect platform
UNAME_S := $(shell uname -s)

# Compiler settings
CC ?= cc
CFLAGS ?= -O2 -fPIC -Wall -Wextra
LDFLAGS ?= -shared

# Output library names
ifeq ($(UNAME_S),Darwin)
    SHIM_LIB = libwebgpu_shim.dylib
    GLFW3WEBGPU_LIB = libglfw3webgpu.dylib
    WGPU_NATIVE_LIB = libwgpu_native.dylib
    WGPU_NATIVE_TARGET = ../deps/wgpu-native/target/release/$(WGPU_NATIVE_LIB)
    UNDEFINED_FLAGS = -Wl,-undefined,dynamic_lookup
else ifeq ($(OS),Windows_NT)
    SHIM_LIB = webgpu_shim.dll
    GLFW3WEBGPU_LIB = glfw3webgpu.dll
    WGPU_NATIVE_LIB = wgpu_native.dll
    WGPU_NATIVE_TARGET = ../deps/wgpu-native/target/release/$(WGPU_NATIVE_LIB)
else
    SHIM_LIB = libwebgpu_shim.so
    GLFW3WEBGPU_LIB = libglfw3webgpu.so
    WGPU_NATIVE_LIB = libwgpu_native.so
    WGPU_NATIVE_TARGET = ../deps/wgpu-native/target/release/$(WGPU_NATIVE_LIB)
endif

# Include paths for headers
CFLAGS += -I../deps/webgpu -I../deps/glfw/include -I../deps/glfw3webgpu

# Platform-specific flags
ifeq ($(UNAME_S),Darwin)
    LDFLAGS += -dynamiclib $(UNDEFINED_FLAGS)
    WGPU_LDFLAGS = -framework Metal -framework CoreGraphics -framework IOKit -framework Cocoa -framework QuartzCore
    GLFW_LDFLAGS = -framework Cocoa -framework IOKit -framework CoreFoundation
    GLFW_DEFINES = -D_GLFW_COCOA
else ifeq ($(OS),Windows_NT)
    GLFW_DEFINES = -D_GLFW_WIN32
else
    # Assume Linux - could be X11 or Wayland, default to X11 for now
    GLFW_DEFINES = -D_GLFW_X11
endif

# GLFW library (shared)
GLFW_LIB = ../deps/glfw/build/src/libglfw.dylib

# Source files
SHIM_SRCS = webgpu_shim.c
SHIM_OBJS = $(SHIM_SRCS:.c=.o)

GLFW3WEBGPU_SRC = ../deps/glfw3webgpu/glfw3webgpu.c

.PHONY: all clean libwgpu-native libglfw

all: $(SHIM_LIB) $(GLFW3WEBGPU_LIB)

# Build the shim library
$(SHIM_LIB): $(SHIM_OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(WGPU_LDFLAGS)

%.o: %.c webgpu_shim.h
	$(CC) $(CFLAGS) -c $< -o $@

# Build glfw3webgpu library
# On macOS we must compile as Objective-C because glfw3webgpu.c includes
# <Foundation/Foundation.h> and <QuartzCore/CAMetalLayer.h>.
$(GLFW3WEBGPU_LIB): $(GLFW3WEBGPU_SRC) $(GLFW_LIB)
ifeq ($(UNAME_S),Darwin)
	$(CC) -x objective-c $(CFLAGS) $(GLFW_DEFINES) $(LDFLAGS) -o $@ $(GLFW3WEBGPU_SRC) -L../deps/glfw/build/src -lglfw $(GLFW_LDFLAGS) $(UNDEFINED_FLAGS)
else
	$(CC) $(CFLAGS) $(GLFW_DEFINES) $(LDFLAGS) -o $@ $(GLFW3WEBGPU_SRC) -L../deps/glfw/build/src -lglfw $(GLFW_LDFLAGS) $(UNDEFINED_FLAGS)
endif

# Build GLFW from source
libglfw:
	@echo "Building GLFW from source..."
	mkdir -p ../deps/glfw/build
	cd ../deps/glfw/build && cmake .. -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF -DCMAKE_BUILD_TYPE=Release
	$(MAKE) -C ../deps/glfw/build -j$$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Build wgpu-native from source in ../deps/wgpu-native
# Requires Rust toolchain with cargo.
libwgpu-native:
	@echo "Building wgpu-native from source..."
	cd ../deps/wgpu-native && cargo build --release
	@echo "Built: $(WGPU_NATIVE_TARGET)"

# Convenience target: build all dependencies and libraries
build-all: libglfw libwgpu-native all

clean:
	rm -f $(SHIM_OBJS) $(SHIM_LIB) $(GLFW3WEBGPU_LIB)
