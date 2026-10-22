-- ==============================================================================
-- 🚀 APPARCHAR - DATOS INICIALES DE PRUEBA (SEED DATA)
-- Puedes ejecutar este archivo en el SQL Editor de Supabase después de correr schema.sql.
-- Inserta parches reales, encuestas, opciones con fotos y vacas sin requerir usuario logueado.
-- ==============================================================================

-- 1. INSERTAR PLANES DE PRUEBA
INSERT INTO public.planes (
  id, title, description, category, cover_image, status, date, location,
  budget_estimated, age_filter, accessibility_filter, gender_filter, creator_id
)
VALUES
(
  'plan-playa-santa-marta',
  'Paseo a la Playa & Rodadero',
  'Decidiendo entre salir sábado en la mañana o domingo bien temprano para aprovechar todo el sol del Caribe.',
  'viaje',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
  'voting',
  'Noviembre 2026',
  'Santa Marta, Magdalena',
  180000,
  '+18',
  'ninguna',
  'mixto',
  NULL
),
(
  'plan-asado-glamping',
  'Asado & Fogata en Guatavita',
  'Parche campestre de fin de semana con fogata, malvaviscos y música acústica.',
  'chill',
  'https://images.unsplash.com/photo-1510312305653-8ed496efae75?auto=format&fit=crop&w=1200&q=80',
  'confirmed',
  'Sáb 21 Nov 2026',
  'Glamping Bosque de la Niebla, Guatavita',
  95000,
  'familiar',
  'pet_friendly',
  'mixto',
  NULL
),
(
  'plan-concierto-estéreo',
  'Festival de Música & Fiesta',
  'Armando grupo para comprar las entradas en combo y cuadrar el transporte ida y vuelta.',
  'concierto',
  'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
  'voting',
  'Por definir',
  'Parque Simón Bolívar, Bogotá',
  250000,
  '+18',
  'silla_ruedas',
  'mixto',
  NULL
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  cover_image = EXCLUDED.cover_image,
  status = EXCLUDED.status,
  budget_estimated = EXCLUDED.budget_estimated;

-- 2. INSERTAR ENCUESTAS PARA LOS PLANES EN VOTACIÓN
INSERT INTO public.encuestas (id, plan_id, time_limit_hours, expires_at, is_closed)
VALUES
(
  'e0000000-0000-0000-0000-000000000001',
  'plan-playa-santa-marta',
  24,
  timezone('utc'::text, now() + interval '24 hours'),
  FALSE
),
(
  'e0000000-0000-0000-0000-000000000002',
  'plan-concierto-estéreo',
  48,
  timezone('utc'::text, now() + interval '48 hours'),
  FALSE
)
ON CONFLICT (plan_id) DO UPDATE SET
  expires_at = EXCLUDED.expires_at,
  is_closed = EXCLUDED.is_closed;

-- 3. INSERTAR OPCIONES DE FECHA Y LUGAR PARA LAS ENCUESTAS
INSERT INTO public.opciones_encuesta (id, poll_id, type, label, sublabel, photo_url)
VALUES
-- Opciones de fecha para Paseo a la Playa
(
  'd0000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'date',
  'Sáb 14 de Noviembre',
  'Salida 6:00 AM',
  NULL
),
(
  'd0000000-0000-0000-0000-000000000002',
  'e0000000-0000-0000-0000-000000000001',
  'date',
  'Dom 15 de Noviembre',
  'Salida 7:30 AM',
  NULL
),
-- Opciones de lugar para Paseo a la Playa
(
  'l0000000-0000-0000-0000-000000000001',
  'e0000000-0000-0000-0000-000000000001',
  'location',
  'Cabaña Vista al Mar',
  'Rodadero Sur, Santa Marta',
  'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?auto=format&fit=crop&w=600&q=80'
),
(
  'l0000000-0000-0000-0000-000000000002',
  'e0000000-0000-0000-0000-000000000001',
  'location',
  'Hostal Playa Cristal',
  'Parque Tayrona, Magdalena',
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=600&q=80'
),
-- Opciones para el Festival de Música
(
  'd0000000-0000-0000-0000-000000000003',
  'e0000000-0000-0000-0000-000000000002',
  'date',
  'Viernes 27 de Noviembre',
  'Apertura de puertas 4:00 PM',
  NULL
),
(
  'd0000000-0000-0000-0000-000000000004',
  'e0000000-0000-0000-0000-000000000002',
  'date',
  'Sábado 28 de Noviembre',
  'Apertura de puertas 2:00 PM',
  NULL
)
ON CONFLICT (id) DO NOTHING;

-- 4. INSERTAR VACAS (FONDOS DE DINERO)
INSERT INTO public.vacas (id, plan_id, target_amount, current_amount)
VALUES
(
  'v0000000-0000-0000-0000-000000000001',
  'plan-asado-glamping',
  380000,
  190000
),
(
  'v0000000-0000-0000-0000-000000000002',
  'plan-playa-santa-marta',
  720000,
  0
)
ON CONFLICT (plan_id) DO UPDATE SET
  target_amount = EXCLUDED.target_amount,
  current_amount = EXCLUDED.current_amount;
