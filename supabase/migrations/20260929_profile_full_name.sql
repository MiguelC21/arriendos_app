-- Agrega nombre completo al perfil de usuario, capturado desde el
-- user_metadata (`full_name`) que la Edge Function admin-users pasa al
-- crear la cuenta.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name', 'viewer')
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;
