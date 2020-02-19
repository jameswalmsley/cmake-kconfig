# cmake-kconfig

Minimal cmake project with kconfig integration adapted from Zephyr.

# Example

Default build using a provided configurations called `test`.

```
mkdir build
cd build
cmake -GNinja -DBOARD=test ..
ninja
```

Note the above uses the config provided by:
```
configs/test_defconfig
```

Updating the configuration:

```
ninja menuconfig
```

This will bring up an interactive menu to turn options on/off and it will
save a .config file in the build directory.

The test_defconfig can be updated by copying the build/.config file to
configs/test_defconfig and committing.

Before any targets are built an autoconf.h header file is generated under:

```
build/kconfig/include/generate/autoconf.h
```

This is allows everything to have a common configuration.

## Cmake
```
if(CONFIG_TEST_OPTION)
    message("Config test_option is enabled")
endif()
```

## Make
```
-include build/.config

ifeq ($(CONFIG_TEST_OPTION),y)
objs += src/test_option.o
endif
```

## C/C++ ...

```
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

