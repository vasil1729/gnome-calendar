#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <rpc.h>
#include <uuid/uuid.h>
#include <stdio.h>
#include <string.h>

void
uuid_generate_random (uuid_t out)
{
	UUID u;

	if (UuidCreate (&u) != RPC_S_OK) {
		memset (out, 0, sizeof (uuid_t));
		return;
	}

	memcpy (out, &u, sizeof (uuid_t));
}

void
uuid_unparse_lower (const uuid_t uu, char *out)
{
	snprintf (out, UUID_STR_LEN,
		"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
		uu[0], uu[1], uu[2], uu[3], uu[4], uu[5], uu[6], uu[7],
		uu[8], uu[9], uu[10], uu[11], uu[12], uu[13], uu[14], uu[15]);
}
