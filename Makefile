# Makefile for webgpu_shim - C shim layer for Common Lisp FFI
#
# This Makefile can also build wgpu-native from deps/wgpu-native.

# Detect platform
UNAME_S := $(shell uname -s)

# Compiler settings
CC ?= cc
CFLAGS ?= -O2 -fPIC -Wall -Wextra
LDFLAGS ?= -shared

# Output library names
ifeq ($(UNAME_S),Darwin)
    SHIM_LIB = libwebgpu_shim.dylib
    GLFW_COMBINED_LIB = shim/libglfw3.dylib
    GLFW_WEBGPU_LIB = shim/libglfw3webgpu.dylib
    GLFW_STATIC = deps/glfw/build/src/libglfw3.a
    WGPU_NATIVE_LIB = libwgpu_native.dylib
    WGPU_NATIVE_TARGET = deps/wgpu-native/target/release/$(WGPU_NATIVE_LIB)
    UNDEFINED_FLAGS = -Wl,-undefined,dynamic_lookup
else ifeq ($(OS),Windows_NT)
    SHIM_LIB = webgpu_shim.dll
    GLFW_COMBINED_LIB = shim/glfw3.dll
    GLFW_STATIC = deps/glfw/build/src/libglfw3.a
    WGPU_NATIVE_LIB = wgpu_native.dll
    WGPU_NATIVE_TARGET = deps/wgpu-native/target/release/$(WGPU_NATIVE_LIB)
else
    SHIM_LIB = libwebgpu_shim.so
    GLFW_COMBINED_LIB = shim/libglfw3.so
    GLFW_STATIC = deps/glfw/build/src/libglfw3.a
    WGPU_NATIVE_LIB = libwgpu_native.so
    WGPU_NATIVE_TARGET = deps/wgpu-native/target/release/$(WGPU_NATIVE_LIB)
endif

# Include paths for headers
CFLAGS += -Ideps/webgpu -Ideps/glfw/include -Ideps/glfw3webgpu -Ishim

# Platform-specific flags
ifeq ($(UNAME_S),Darwin)
    LDFLAGS += -dynamiclib $(UNDEFINED_FLAGS)
    WGPU_LDFLAGS = -framework Metal -framework CoreGraphics -framework IOKit -framework Cocoa -framework QuartzCore
    GLFW_LDFLAGS = -framework Cocoa -framework IOKit -framework CoreFoundation -framework CoreVideo -framework QuartzCore
    GLFW_DEFINES = -D_GLFW_COCOA
else ifeq ($(OS),Windows_NT)
    GLFW_DEFINES = -D_GLFW_WIN32
else
    # Assume Linux - could be X11 or Wayland, default to X11 for now
    GLFW_DEFINES = -D_GLFW_X11
endif

# Source files
SHIM_SRCS = shim/webgpu_shim.c
SHIM_OBJS = $(SHIM_SRCS:.c=.o)

GLFW3WEBGPU_SRC = deps/glfw3webgpu/glfw3webgpu.c

.PHONY: all clean libwgpu-native libglfw

all: $(SHIM_LIB) $(GLFW_WEBGPU_LIB)

# Build the shim library
$(SHIM_LIB): $(SHIM_OBJS)
	$(CC) $(LDFLAGS) -o $@ $^ $(WGPU_LDFLAGS)

shim/%.o: shim/%.c shim/webgpu_shim.h
	$(CC) $(CFLAGS) -c $< -o $@

# Build glfw3webgpu bridge library.
# Uses -undefined dynamic_lookup so it shares whatever GLFW instance is
# already loaded in the process (e.g. from cl-glfw3 / homebrew GLFW).
$(GLFW_WEBGPU_LIB): $(GLFW3WEBGPU_SRC)
ifeq ($(UNAME_S),Darwin)
	$(CC) -x objective-c $(CFLAGS) $(GLFW_DEFINES) -dynamiclib \
	  -I deps/glfw/include -I deps/webgpu -I deps/glfw3webgpu \
	  -DGLFW_EXPOSE_NATIVE_COCOA \
	  $(GLFW3WEBGPU_SRC) \
	  $(UNDEFINED_FLAGS) \
	  -framework Cocoa -framework IOKit -framework QuartzCore \
	  -install_name @rpath/libglfw3webgpu.dylib \
	  -o $@
else
	$(CC) $(CFLAGS) $(GLFW_DEFINES) -shared \
	  -I deps/glfw/include -I deps/webgpu -I deps/glfw3webgpu \
	  $(GLFW3WEBGPU_SRC) \
	  $(UNDEFINED_FLAGS) \
	  -o $@
endif

# Build combined GLFW + glfw3webgpu shared lib (requires GLFW static build first)
$(GLFW_COMBINED_LIB): $(GLFW_STATIC)
ifeq ($(UNAME_S),Darwin)
	$(CC) -x objective-c $(CFLAGS) $(GLFW_DEFINES) -dynamiclib \
	  -I deps/glfw/include -I deps/webgpu -I deps/glfw3webgpu \
	  -DGLFW_EXPOSE_NATIVE_COCOA \
	  $(GLFW3WEBGPU_SRC) \
	  -all_load $(GLFW_STATIC) \
	  $(GLFW_LDFLAGS) \
	  -o $@
else
	$(CC) $(CFLAGS) $(GLFW_DEFINES) -shared \
	  -I deps/glfw/include -I deps/webgpu -I deps/glfw3webgpu \
	  $(GLFW3WEBGPU_SRC) \
	  -Wl,--whole-archive $(GLFW_STATIC) -Wl,--no-whole-archive \
	  $(GLFW_LDFLAGS) \
	  $(UNDEFINED_FLAGS) \
	  -o $@
endif

# Build GLFW as a static library from source
libglfw: $(GLFW_STATIC)

$(GLFW_STATIC):
	@echo "Building GLFW (static) from source..."
	mkdir -p deps/glfw/build
	cd deps/glfw/build && cmake .. \
	  -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
	  -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release
	$(MAKE) -C deps/glfw/build -j$$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Build wgpu-native from source in deps/wgpu-native
# Requires Rust toolchain with cargo.
libwgpu-native:
	@echo "Building wgpu-native from source..."
	cd deps/wgpu-native && cargo build --release
	@echo "Built: $(WGPU_NATIVE_TARGET)"

# Convenience target: build all dependencies and libraries
build-all: libglfw libwgpu-native all

clean:
	rm -f $(SHIM_OBJS) $(SHIM_LIB) $(GLFW_WEBGPU_LIB) $(GLFW_COMBINED_LIB)
