# cmake-kconfig

Minimal cmake project with Kconfig integration adapted from Zephyr.

All Zephyr-related stuff was removed and adopted to be used in standalone projects.

# Example

Default build using a provided configurations called `test`.

```bash
cmake -B build -DBUILD_CONFIG=test -GNinja
cmake --build build
./build/test1
```

Note the above uses the config provided by:
```
configs/test_defconfig
```

Updating the configuration:

```bash
ninja -C build menuconfig
```

This will bring up an interactive menu to turn options on/off and it will
save a .config file in the build directory.

The test_defconfig can be updated by copying the build/.config file to
configs/test_defconfig and committing.

Before any targets are built an autoconf.h header file is generated in `${AUTOCONF_DIR}`:

```
build/kconfig/include/generate/autoconf.h
```

This allows everything to have a common configuration.

Auto-generated `autoconf.h` resides in `${AUTOCONF_DIR}`, add it to your target's include search path:
```CMake
target_include_directories(your_target PUBLIC ${AUTOCONF_DIR})
```

## Cmake
```CMake
if(CONFIG_TEST_OPTION)
    message("Config test_option is enabled")
endif()
```

## Make
```Makefile
-include build/.config

ifeq ($(CONFIG_TEST_OPTION),y)
objs += src/test_option.o
endif
```

## C/C++ ...

```cpp
#include <autoconf.h>

#ifdef CONFIG_TEST_OPTION
// Code built for option.
#endif
```
# Kconfig

Kconfig is Brilliant! It manages a unified configuration separately from
the main source code that can be used with the build system and source code.

It is the best-in-class configuration management tool that exists for embedded
C code, period.

It allows dependencies to be defined between different config options.
And the best thing is, some really smart people have worked all this out before,
so we get a really powerful system for little effort/cost.

