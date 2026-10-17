#ifndef PRIMITIVES_IOSURFACE_H
#define PRIMITIVES_IOSURFACE_H

#include <stdbool.h>
#include <stdint.h>

int IOSurface_map(uint64_t phys, uint64_t size, void **addressOut);
int IOSurface_map_withCacheMode(uint64_t phys, uint64_t size, void **addressOut, uint32_t cacheMode);
uint64_t IOSurface_kalloc(uint64_t size, bool leak);
int IOSurface_kalloc_global(uint64_t *addr, uint64_t size);
int IOSurface_kalloc_local(uint64_t *addr, uint64_t size);
void libjailbreak_IOSurface_kalloc_init(void);
void libjailbreak_IOSurface_primitives_init(void);
void IOSurface_map_cleanup(void);

#endif
