#ifndef GEOCLUE_H
#define GEOCLUE_H

#include <glib-object.h>
#include <gio/gio.h>

G_BEGIN_DECLS

typedef enum {
	GCLUE_ACCURACY_LEVEL_NONE = 0,
	GCLUE_ACCURACY_LEVEL_COUNTRY = 1,
	GCLUE_ACCURACY_LEVEL_CITY = 4,
	GCLUE_ACCURACY_LEVEL_NEIGHBORHOOD = 5,
	GCLUE_ACCURACY_LEVEL_STREET = 6,
	GCLUE_ACCURACY_LEVEL_EXACT = 8
} GClueAccuracyLevel;

#define GCLUE_TYPE_SIMPLE (gclue_simple_get_type ())
#define GCLUE_TYPE_LOCATION (gclue_location_get_type ())
#define GCLUE_TYPE_CLIENT (gclue_client_get_type ())

G_DECLARE_FINAL_TYPE (GClueSimple, gclue_simple, GCLUE, SIMPLE, GObject)
G_DECLARE_FINAL_TYPE (GClueLocation, gclue_location, GCLUE, LOCATION, GObject)
G_DECLARE_FINAL_TYPE (GClueClient, gclue_client, GCLUE, CLIENT, GObject)

void gclue_simple_new (const char *desktop_id,
		       GClueAccuracyLevel accuracy_level,
		       GCancellable *cancellable,
		       GAsyncReadyCallback callback,
		       gpointer user_data);
GClueSimple *gclue_simple_new_finish (GAsyncResult *res, GError **error);
GClueLocation *gclue_simple_get_location (GClueSimple *simple);
GClueClient *gclue_simple_get_client (GClueSimple *simple);

gdouble gclue_location_get_latitude (GClueLocation *location);
gdouble gclue_location_get_longitude (GClueLocation *location);

void gclue_client_call_stop (GClueClient *client,
			     GCancellable *cancellable,
			     GAsyncReadyCallback callback,
			     gpointer user_data);
gboolean gclue_client_call_stop_finish (GClueClient *client,
					GAsyncResult *res,
					GError **error);

G_END_DECLS

#endif
