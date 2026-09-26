-- Habilita Supabase Realtime (postgres_changes) para que los cambios en estas
-- tablas se transmitan a todos los dispositivos conectados y disparen una
-- sincronización automática, en vez de esperar a que el usuario la fuerce.
ALTER PUBLICATION supabase_realtime ADD TABLE public.buildings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.units;
ALTER PUBLICATION supabase_realtime ADD TABLE public.contracts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.monthly_payments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.abonos;
