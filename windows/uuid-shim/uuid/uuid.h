#ifndef EVO_UUID_SHIM_H
#define EVO_UUID_SHIM_H

#include <stddef.h>

#ifdef uuid_t
#undef uuid_t
#endif

#ifdef UUID_STR_LEN
#undef UUID_STR_LEN
#endif

#define UUID_STR_LEN 37

typedef unsigned char uuid_t[16];

void uuid_generate_random(uuid_t out);
void uuid_unparse_lower(const uuid_t uu, char *out);

#endif
