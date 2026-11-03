#include "geoclue.h"

struct _GClueSimple {
	GObject parent_instance;
	GClueClient *client;
};

struct _GClueLocation {
	GObject parent_instance;
};

struct _GClueClient {
	GObject parent_instance;
};

G_DEFINE_TYPE (GClueSimple, gclue_simple, G_TYPE_OBJECT)
G_DEFINE_TYPE (GClueLocation, gclue_location, G_TYPE_OBJECT)
G_DEFINE_TYPE (GClueClient, gclue_client, G_TYPE_OBJECT)

static void
gclue_simple_finalize (GObject *object)
{
	GClueSimple *self = GCLUE_SIMPLE (object);

	g_clear_object (&self->client);

	G_OBJECT_CLASS (gclue_simple_parent_class)->finalize (object);
}

static void
gclue_simple_class_init (GClueSimpleClass *klass)
{
	G_OBJECT_CLASS (klass)->finalize = gclue_simple_finalize;
}

static void
gclue_simple_init (GClueSimple *self)
{
	self->client = g_object_new (GCLUE_TYPE_CLIENT, NULL);
}

static void
gclue_location_class_init (GClueLocationClass *klass)
{
}

static void
gclue_location_init (GClueLocation *self)
{
}

static void
gclue_client_class_init (GClueClientClass *klass)
{
}

static void
gclue_client_init (GClueClient *self)
{
}

static void
simple_new_thread (GTask *task,
		   gpointer source_object,
		   gpointer task_data,
		   GCancellable *cancellable)
{
	g_task_return_pointer (task, g_object_new (GCLUE_TYPE_SIMPLE, NULL), g_object_unref);
}

void
gclue_simple_new (const char *desktop_id,
		  GClueAccuracyLevel accuracy_level,
		  GCancellable *cancellable,
		  GAsyncReadyCallback callback,
		  gpointer user_data)
{
	GTask *task;

	task = g_task_new (NULL, cancellable, callback, user_data);
	g_task_set_source_tag (task, (gpointer) gclue_simple_new);
	g_task_run_in_thread (task, simple_new_thread);
	g_object_unref (task);
}

GClueSimple *
gclue_simple_new_finish (GAsyncResult *res,
			 GError **error)
{
	return g_task_propagate_pointer (G_TASK (res), error);
}

GClueLocation *
gclue_simple_get_location (GClueSimple *simple)
{
	g_return_val_if_fail (GCLUE_IS_SIMPLE (simple), NULL);

	return NULL;
}

GClueClient *
gclue_simple_get_client (GClueSimple *simple)
{
	g_return_val_if_fail (GCLUE_IS_SIMPLE (simple), NULL);

	return simple->client;
}

gdouble
gclue_location_get_latitude (GClueLocation *location)
{
	return 0.0;
}

gdouble
gclue_location_get_longitude (GClueLocation *location)
{
	return 0.0;
}

void
gclue_client_call_stop (GClueClient *client,
			GCancellable *cancellable,
			GAsyncReadyCallback callback,
			gpointer user_data)
{
	GTask *task;

	task = g_task_new (client, cancellable, callback, user_data);
	g_task_set_source_tag (task, (gpointer) gclue_client_call_stop);
	g_task_return_boolean (task, TRUE);
	g_object_unref (task);
}

gboolean
gclue_client_call_stop_finish (GClueClient *client,
			       GAsyncResult *res,
			       GError **error)
{
	return g_task_propagate_boolean (G_TASK (res), error);
}
