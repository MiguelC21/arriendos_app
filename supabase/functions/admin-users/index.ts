// Edge Function: admin-users
// Acciones privilegiadas sobre cuentas de usuario (crear cuenta, resetear
// contraseña de un tercero) que requieren la service_role key de Supabase.
// Esa clave NUNCA viaja en el cliente Flutter; solo vive aquí, del lado
// servidor. Cada llamada valida que quien invoca sea admin o developer antes
// de ejecutar la acción.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "No autenticado." }, 401);
  }

  try {
    // Cliente "como el usuario que llama" — sirve para validar su identidad
    // y consultar su propio rol respetando RLS.
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: callerData, error: callerError } = await callerClient.auth
      .getUser();
    if (callerError || !callerData.user) {
      return jsonResponse({ error: "Sesión inválida." }, 401);
    }

    const { data: callerProfile, error: profileError } = await callerClient
      .from("profiles")
      .select("role")
      .eq("id", callerData.user.id)
      .single();

    if (profileError || !callerProfile) {
      return jsonResponse({ error: "No se pudo verificar el rol del usuario." }, 403);
    }

    const callerRole = callerProfile.role as string;
    if (callerRole !== "admin" && callerRole !== "developer") {
      return jsonResponse(
        { error: "No tienes permiso para gestionar usuarios." },
        403,
      );
    }

    const body = await req.json();
    const action = body.action as string;

    // Cliente con privilegios de administrador (service_role) — solo se usa
    // después de confirmar arriba que quien llama es admin/developer.
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    if (action === "create") {
      const { email, password, role, fullName } = body as {
        email: string;
        password: string;
        role: string;
        fullName?: string;
      };

      if (!email || !password || !role) {
        return jsonResponse({ error: "Faltan datos (email, password, role)." }, 400);
      }
      if (!["developer", "admin", "viewer"].includes(role)) {
        return jsonResponse({ error: "Rol inválido." }, 400);
      }
      if (role === "developer" && callerRole !== "developer") {
        return jsonResponse(
          { error: "Solo un Developer puede crear otra cuenta Developer." },
          403,
        );
      }

      const { data: created, error: createError } = await adminClient.auth
        .admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: fullName ? { full_name: fullName } : undefined,
        });

      if (createError || !created.user) {
        return jsonResponse({
          error: createError?.message ?? "No se pudo crear el usuario.",
        }, 400);
      }

      const { error: roleUpdateError } = await adminClient
        .from("profiles")
        .update({ role, full_name: fullName ?? null })
        .eq("id", created.user.id);

      if (roleUpdateError) {
        return jsonResponse({
          error: `Usuario creado pero no se pudo asignar el rol: ${roleUpdateError.message}`,
        }, 500);
      }

      return jsonResponse({ success: true, userId: created.user.id });
    }

    if (action === "reset-password") {
      const { userId, newPassword } = body as {
        userId: string;
        newPassword: string;
      };

      if (!userId || !newPassword) {
        return jsonResponse({ error: "Faltan datos (userId, newPassword)." }, 400);
      }

      const { error: updateError } = await adminClient.auth.admin
        .updateUserById(userId, { password: newPassword });

      if (updateError) {
        return jsonResponse({ error: updateError.message }, 400);
      }

      return jsonResponse({ success: true });
    }

    if (action === "delete") {
      const { userId } = body as { userId: string };

      if (!userId) {
        return jsonResponse({ error: "Falta userId." }, 400);
      }
      if (userId === callerData.user.id) {
        return jsonResponse({ error: "No puedes eliminar tu propia cuenta." }, 400);
      }

      const { data: targetProfile } = await adminClient
        .from("profiles")
        .select("role")
        .eq("id", userId)
        .single();

      if (targetProfile?.role === "developer" && callerRole !== "developer") {
        return jsonResponse(
          { error: "Solo un Developer puede eliminar otra cuenta Developer." },
          403,
        );
      }

      const { error: deleteError } = await adminClient.auth.admin.deleteUser(
        userId,
      );

      if (deleteError) {
        return jsonResponse({ error: deleteError.message }, 400);
      }

      return jsonResponse({ success: true });
    }

    return jsonResponse({ error: "Acción desconocida." }, 400);
  } catch (e) {
    return jsonResponse({ error: `Error interno: ${e}` }, 500);
  }
});
