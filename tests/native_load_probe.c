#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    if (!dlopen(argv[1], RTLD_NOW | RTLD_LOCAL)) {
        fprintf(stderr, "%s\n", dlerror());
        return 3;
    }
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "/SplineRuntime.framework/") || strstr(name, "/SoulverCore.framework/")) {
            fprintf(stderr, "Unexpected framework dependency: %s\n", name);
            return 4;
        }
    }
    if (!objc_getClass("_TtC10RaycastApp18RaycastNotesWindow")) return 5;
    puts("Core loads and Notes class registers without the removed frameworks");
    return 0;
}
