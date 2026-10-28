#include "dynamic.h"

#include <stdio.h>

#ifdef _WIN32
#include <windows.h>
static HMODULE win32_dlopen(const char* path) {
    if (!path) return NULL;
    char dir_path[MAX_PATH];
    strncpy(dir_path, path, MAX_PATH - 1);
    dir_path[MAX_PATH - 1] = '\0';
    char* last_slash = strrchr(dir_path, '\\');
    if (!last_slash) last_slash = strrchr(dir_path, '/');
    if (last_slash) {
        *last_slash = '\0';
        SetDllDirectoryA(dir_path);
    }
    HMODULE h = LoadLibraryExA(path, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!h) {
        h = LoadLibraryA(path);
    }
    if (last_slash) {
        SetDllDirectoryA(NULL);
    }
    return h;
}
#define DLOPEN(path) win32_dlopen(path)
#define DLCLOSE(handle) FreeLibrary((HMODULE)(handle))
#else
#ifdef __APPLE__
#include <mach-o/dyld.h>
#include <libgen.h>
#endif
#include <dlfcn.h>
#define DLOPEN(path) dlopen(path, RTLD_LAZY | RTLD_GLOBAL)
#define DLCLOSE(handle) dlclose(handle)
#endif

static int mlx_dynamic_open(mlx_dynamic_handle* handle, const char* path) {
    handle->ctx = (void*) DLOPEN(path);
    if (handle->ctx == NULL) {
        return 1;
    }
    return 0;
}

int mlx_dynamic_load(mlx_dynamic_handle* handle, const char *path) {
    return mlx_dynamic_open(handle, path);
}

void mlx_dynamic_unload(mlx_dynamic_handle* handle) {
    if (handle->ctx) {
        DLCLOSE(handle->ctx);
        handle->ctx = NULL;
    }
}
