-- Limpia pagos mensuales duplicados (mismo contrato + año + mes) y evita que
-- vuelvan a crearse.
--
-- Causa: cada dispositivo generaba el pago del mes con un id aleatorio; dos
-- dispositivos sin sincronizar creaban cada uno su propia fila.
--
-- Qué hace, dentro de una sola transacción (si algo falla, no cambia nada):
--   1. Por cada (contrato, año, mes) repetido conserva UNA fila: la que tenga
--      más abonos; si empatan, la de mayor paid_value; luego la más antigua.
--   2. Mueve a esa fila los abonos de las filas repetidas (no se pierde ningún
--      abono).
--   3. Borra las filas repetidas.
--   4. Recalcula paid_value / status / is_fully_paid de las filas conservadas
--      a partir de la suma real de sus abonos (misma regla que usa la app).
--   5. Crea un índice único para que la base rechace futuros duplicados.
--
-- ANTES DE EJECUTAR: corre esta consulta para ver qué se va a limpiar.
--
--   select contract_id, year, month, count(*) as filas,
--          array_agg(id order by created_at) as ids
--   from public.monthly_payments
--   group by contract_id, year, month
--   having count(*) > 1
--   order by year, month;
--
-- Aplicar en el SQL Editor de Supabase (Local y/o Producción).

begin;

create temp table _dup_map on commit drop as
with abono_count as (
    select payment_id, count(*) as n
    from public.abonos
    group by payment_id
),
ranked as (
    select
        p.id,
        row_number() over w as rn,
        first_value(p.id) over w as keeper_id
    from public.monthly_payments p
    left join abono_count ac on ac.payment_id = p.id
    window w as (
        partition by p.contract_id, p.year, p.month
        order by coalesce(ac.n, 0) desc, p.paid_value desc, p.created_at asc, p.id asc
    )
)
select id as dup_id, keeper_id
from ranked
where rn > 1;

-- 2. Reasignar abonos de las filas repetidas a la fila que se conserva.
update public.abonos a
set payment_id = m.keeper_id
from _dup_map m
where a.payment_id = m.dup_id;

-- 3. Borrar las filas repetidas (ya sin abonos que las referencien).
delete from public.monthly_payments p
using _dup_map m
where p.id = m.dup_id;

-- 4. Recalcular totales de las filas conservadas.
update public.monthly_payments p
set
    paid_value    = s.total,
    is_fully_paid = s.total >= p.total_value - 0.1,
    status        = case
        when s.total >= p.total_value - 0.1 then 'pagado'
        when s.total > 0.1 then 'parcial'
        else 'pendiente'
    end
from (
    select k.keeper_id as id,
           coalesce((select sum(a.amount) from public.abonos a where a.payment_id = k.keeper_id), 0) as total
    from (select distinct keeper_id from _dup_map) k
) s
where p.id = s.id;

-- 5. Impedir futuros duplicados.
create unique index if not exists uq_monthly_payments_contract_period
    on public.monthly_payments (contract_id, year, month);

commit;
