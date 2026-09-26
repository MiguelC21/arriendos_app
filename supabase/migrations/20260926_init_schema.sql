-- Migración inicial para Arriendos App (Supabase Local y Pruebas)
-- Tablas: buildings, units, contracts, monthly_payments, abonos

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. BUILDINGS
CREATE TABLE IF NOT EXISTS public.buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. UNITS
CREATE TABLE IF NOT EXISTS public.units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    number TEXT NOT NULL,
    base_value NUMERIC NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. CONTRACTS
CREATE TABLE IF NOT EXISTS public.contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id UUID NOT NULL REFERENCES public.units(id) ON DELETE CASCADE,
    tenant_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    contract_value NUMERIC NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. MONTHLY PAYMENTS
CREATE TABLE IF NOT EXISTS public.monthly_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID NOT NULL REFERENCES public.contracts(id) ON DELETE CASCADE,
    month INTEGER NOT NULL,
    year INTEGER NOT NULL,
    total_value NUMERIC NOT NULL DEFAULT 0,
    paid_value NUMERIC NOT NULL DEFAULT 0,
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pendiente',
    is_fully_paid BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. ABONOS
CREATE TABLE IF NOT EXISTS public.abonos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES public.monthly_payments(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL DEFAULT 0,
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ÍNDICES PARA MEJOR RENDIMIENTO
CREATE INDEX IF NOT EXISTS idx_units_building_id ON public.units(building_id);
CREATE INDEX IF NOT EXISTS idx_contracts_unit_id ON public.contracts(unit_id);
CREATE INDEX IF NOT EXISTS idx_contracts_active ON public.contracts(active);
CREATE INDEX IF NOT EXISTS idx_monthly_payments_contract_id ON public.monthly_payments(contract_id);
CREATE INDEX IF NOT EXISTS idx_monthly_payments_date ON public.monthly_payments(year, month);
CREATE INDEX IF NOT EXISTS idx_abonos_payment_id ON public.abonos(payment_id);

-- POLÍTICAS RLS (Row Level Security) BÁSICAS PARA ACCESO ANÓNIMO / PÚBLICO
ALTER TABLE public.buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.abonos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir todo en buildings" ON public.buildings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Permitir todo en units" ON public.units FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Permitir todo en contracts" ON public.contracts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Permitir todo en monthly_payments" ON public.monthly_payments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Permitir todo en abonos" ON public.abonos FOR ALL USING (true) WITH CHECK (true);
