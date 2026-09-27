-- Roles de usuario: Developer / Admin / Usuario normal (viewer)
-- Aplicar esta migración tanto en el proyecto Supabase LOCAL como en PRODUCCIÓN.

-- 1. TABLA DE PERFILES
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('developer', 'admin', 'viewer')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. TRIGGER: crear perfil automáticamente al crear un usuario de Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, role)
    VALUES (NEW.id, NEW.email, 'viewer')
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. FUNCIÓN AUXILIAR: rol del usuario autenticado actual
-- SECURITY DEFINER evita la recursión de RLS al usarla dentro de otras políticas.
CREATE OR REPLACE FUNCTION public.current_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- 4. RLS DE profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver perfil propio o todos si admin/developer" ON public.profiles;
CREATE POLICY "Ver perfil propio o todos si admin/developer" ON public.profiles
    FOR SELECT USING (
        auth.uid() = id OR public.current_role() IN ('admin', 'developer')
    );

DROP POLICY IF EXISTS "Admin/Developer actualizan perfiles" ON public.profiles;
CREATE POLICY "Admin/Developer actualizan perfiles" ON public.profiles
    FOR UPDATE USING (
        public.current_role() IN ('admin', 'developer')
    ) WITH CHECK (
        public.current_role() IN ('admin', 'developer')
    );

-- 5. RLS DE LAS TABLAS DE NEGOCIO
-- Se reemplaza el acceso público total por: lectura para cualquier usuario
-- autenticado, escritura solo para admin/developer.
DROP POLICY IF EXISTS "Permitir todo en buildings" ON public.buildings;
DROP POLICY IF EXISTS "Permitir todo en units" ON public.units;
DROP POLICY IF EXISTS "Permitir todo en contracts" ON public.contracts;
DROP POLICY IF EXISTS "Permitir todo en monthly_payments" ON public.monthly_payments;
DROP POLICY IF EXISTS "Permitir todo en abonos" ON public.abonos;

DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['buildings', 'units', 'contracts', 'monthly_payments', 'abonos']
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS "Lectura autenticada en %1$s" ON public.%1$s;', t
        );
        EXECUTE format(
            'CREATE POLICY "Lectura autenticada en %1$s" ON public.%1$s FOR SELECT USING (auth.uid() IS NOT NULL);', t
        );

        EXECUTE format(
            'DROP POLICY IF EXISTS "Escritura admin/developer en %1$s" ON public.%1$s;', t
        );
        EXECUTE format(
            'CREATE POLICY "Escritura admin/developer en %1$s" ON public.%1$s FOR INSERT WITH CHECK (public.current_role() IN (''admin'', ''developer''));', t
        );
        EXECUTE format(
            'DROP POLICY IF EXISTS "Actualizacion admin/developer en %1$s" ON public.%1$s;', t
        );
        EXECUTE format(
            'CREATE POLICY "Actualizacion admin/developer en %1$s" ON public.%1$s FOR UPDATE USING (public.current_role() IN (''admin'', ''developer'')) WITH CHECK (public.current_role() IN (''admin'', ''developer''));', t
        );
        EXECUTE format(
            'DROP POLICY IF EXISTS "Eliminacion admin/developer en %1$s" ON public.%1$s;', t
        );
        EXECUTE format(
            'CREATE POLICY "Eliminacion admin/developer en %1$s" ON public.%1$s FOR DELETE USING (public.current_role() IN (''admin'', ''developer''));', t
        );
    END LOOP;
END $$;
