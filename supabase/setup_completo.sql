-- ==============================================================================
-- 🚀 APPARCHAR - CONFIGURACIÓN Y ACTUALIZACIÓN COMPLETA DE BASE DE DATOS SUPABASE
-- Script Idempotente: Crea/actualiza tablas, RLS, triggers, storage y catálogos
-- Ejecuta este script completo en el SQL Editor de tu proyecto Supabase.
-- ==============================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA extensions;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ==============================================================================
-- 2. TABLAS PRINCIPALES (EN ESPAÑOL)
-- ==============================================================================

-- A) PERFILES (Vinculado a auth.users de Supabase)
CREATE TABLE IF NOT EXISTS public.perfiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  streak INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- B) AMISTADES (Relación entre dos usuarios y su círculo)
CREATE TABLE IF NOT EXISTS public.amistades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  amigo_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  circulo TEXT NOT NULL DEFAULT 'cercano' CHECK (circulo IN ('intimo', 'cercano', 'comunidad')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(user_id, amigo_id)
);

-- C) CATEGORÍAS DE PLANES (Catálogo con presets de fotos)
CREATE TABLE IF NOT EXISTS public.categorias_plan (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  icono TEXT,
  portadas_preset TEXT[] NOT NULL DEFAULT '{}'
);

-- D) CATÁLOGO DE FILTROS DEL SISTEMA (Edad, accesibilidad, género, círculos)
CREATE TABLE IF NOT EXISTS public.catalogo_filtros (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo TEXT NOT NULL CHECK (tipo IN ('edad', 'accesibilidad', 'genero', 'circulo')),
  clave TEXT NOT NULL,
  etiqueta TEXT NOT NULL,
  descripcion TEXT,
  UNIQUE(tipo, clave)
);

-- E) PLANES (Parches)
CREATE TABLE IF NOT EXISTS public.planes (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL,
  cover_image TEXT,
  status TEXT NOT NULL DEFAULT 'voting' CHECK (status IN ('voting', 'confirmed', 'history', 'cancelled')),
  date TEXT DEFAULT 'Por definir',
  location TEXT DEFAULT 'Por definir',
  budget_estimated NUMERIC DEFAULT 0,
  
  -- Filtros de audiencia
  age_filter TEXT NOT NULL DEFAULT 'todos',
  accessibility_filter TEXT NOT NULL DEFAULT 'ninguna',
  gender_filter TEXT NOT NULL DEFAULT 'mixto',
  
  creator_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- F) LUGARES SUGERIDOS (Presets para creación de encuestas)
CREATE TABLE IF NOT EXISTS public.lugares_sugeridos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  sublabel TEXT,
  categoria TEXT REFERENCES public.categorias_plan(id) ON DELETE SET NULL,
  foto_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- G) MIEMBROS DEL PLAN (Invitados y organizadores)
CREATE TABLE IF NOT EXISTS public.miembros_plan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id TEXT NOT NULL REFERENCES public.planes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'parcheador' CHECK (role IN ('organizador', 'tesorero', 'parcheador', 'invitado')),
  status TEXT NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'accepted', 'declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(plan_id, user_id)
);

-- H) ENCUESTAS Y TEMPORIZADOR
CREATE TABLE IF NOT EXISTS public.encuestas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id TEXT NOT NULL UNIQUE REFERENCES public.planes(id) ON DELETE CASCADE,
  time_limit_hours INTEGER NOT NULL DEFAULT 24 CHECK (time_limit_hours IN (12, 24, 48, 72)),
  expires_at TIMESTAMPTZ NOT NULL,
  is_closed BOOLEAN NOT NULL DEFAULT FALSE,
  winning_date_option_id UUID,
  winning_location_option_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- I) OPCIONES DE ENCUESTA (Fechas y lugares)
CREATE TABLE IF NOT EXISTS public.opciones_encuesta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.encuestas(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('date', 'location')),
  label TEXT NOT NULL,
  sublabel TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_opcion_fecha_ganadora'
  ) THEN
    ALTER TABLE public.encuestas 
      ADD CONSTRAINT fk_opcion_fecha_ganadora FOREIGN KEY (winning_date_option_id) REFERENCES public.opciones_encuesta(id) ON DELETE SET NULL,
      ADD CONSTRAINT fk_opcion_lugar_ganador FOREIGN KEY (winning_location_option_id) REFERENCES public.opciones_encuesta(id) ON DELETE SET NULL;
  END IF;
END $$;

-- J) VOTOS DE ENCUESTAS
CREATE TABLE IF NOT EXISTS public.votos_encuesta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.encuestas(id) ON DELETE CASCADE,
  option_id UUID NOT NULL REFERENCES public.opciones_encuesta(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(option_id, user_id)
);

-- K) VACAS Y FINANZAS
CREATE TABLE IF NOT EXISTS public.vacas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id TEXT NOT NULL UNIQUE REFERENCES public.planes(id) ON DELETE CASCADE,
  target_amount NUMERIC NOT NULL DEFAULT 0,
  current_amount NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.aportes_vaca (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vaca_id UUID NOT NULL REFERENCES public.vacas(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 3. TRIGGERS Y FUNCIONES AUTOMÁTICAS
-- ==============================================================================

-- Trigger para crear perfil automáticamente al registrarse en auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfiles (id, full_name, username, avatar_url, role, streak)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Parcheador'),
    COALESCE(NEW.raw_user_meta_data->>'user_name', split_part(NEW.email, '@', 1) || '_' || substr(NEW.id::text, 1, 4)),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'picture', NULL),
    'user',
    1
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name,
      avatar_url = EXCLUDED.avatar_url,
      updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger para updated_at automático
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at_perfiles ON public.perfiles;
CREATE TRIGGER set_updated_at_perfiles
  BEFORE UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_planes ON public.planes;
CREATE TRIGGER set_updated_at_planes
  BEFORE UPDATE ON public.planes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_encuestas ON public.encuestas;
CREATE TRIGGER set_updated_at_encuestas
  BEFORE UPDATE ON public.encuestas
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_vacas ON public.vacas;
CREATE TRIGGER set_updated_at_vacas
  BEFORE UPDATE ON public.vacas
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Trigger para acumular aportes en la vaca
CREATE OR REPLACE FUNCTION public.handle_vaca_aporte()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.vacas
  SET current_amount = current_amount + NEW.amount,
      updated_at = timezone('utc'::text, now())
  WHERE id = NEW.vaca_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_vaca_aporte ON public.aportes_vaca;
CREATE TRIGGER on_vaca_aporte
  AFTER INSERT ON public.aportes_vaca
  FOR EACH ROW EXECUTE FUNCTION public.handle_vaca_aporte();

-- ==============================================================================
-- 4. SEGURIDAD: ROW LEVEL SECURITY (RLS)
-- ==============================================================================

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amistades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categorias_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_filtros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lugares_sugeridos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.miembros_plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.encuestas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.opciones_encuesta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votos_encuesta ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vacas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aportes_vaca ENABLE ROW LEVEL SECURITY;

-- Políticas PERFILES
DROP POLICY IF EXISTS "Perfiles públicos para autenticados" ON public.perfiles;
CREATE POLICY "Perfiles públicos para autenticados"
  ON public.perfiles FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios actualizan solo su propio perfil" ON public.perfiles;
CREATE POLICY "Usuarios actualizan solo su propio perfil"
  ON public.perfiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Insertar mi propio perfil" ON public.perfiles;
CREATE POLICY "Insertar mi propio perfil"
  ON public.perfiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- Políticas AMISTADES
DROP POLICY IF EXISTS "Ver mis amistades" ON public.amistades;
CREATE POLICY "Ver mis amistades"
  ON public.amistades FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id OR auth.uid() = amigo_id);

DROP POLICY IF EXISTS "Crear amistad" ON public.amistades;
CREATE POLICY "Crear amistad"
  ON public.amistades FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Actualizar circulo de amistad" ON public.amistades;
CREATE POLICY "Actualizar circulo de amistad"
  ON public.amistades FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Eliminar amistad" ON public.amistades;
CREATE POLICY "Eliminar amistad"
  ON public.amistades FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Políticas CATEGORÍAS Y FILTROS (Lectura pública)
DROP POLICY IF EXISTS "Lectura pública de categorías" ON public.categorias_plan;
CREATE POLICY "Lectura pública de categorías"
  ON public.categorias_plan FOR SELECT
  TO public
  USING (true);

DROP POLICY IF EXISTS "Lectura pública de filtros" ON public.catalogo_filtros;
CREATE POLICY "Lectura pública de filtros"
  ON public.catalogo_filtros FOR SELECT
  TO public
  USING (true);

DROP POLICY IF EXISTS "Lectura pública de lugares" ON public.lugares_sugeridos;
CREATE POLICY "Lectura pública de lugares"
  ON public.lugares_sugeridos FOR SELECT
  TO public
  USING (true);

-- Políticas PLANES
DROP POLICY IF EXISTS "Lectura de planes para usuarios autenticados" ON public.planes;
CREATE POLICY "Lectura de planes para usuarios autenticados"
  ON public.planes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Lectura de planes públicos para invitaciones anónimas" ON public.planes;
CREATE POLICY "Lectura de planes públicos para invitaciones anónimas"
  ON public.planes FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden crear planes" ON public.planes;
CREATE POLICY "Usuarios autenticados pueden crear planes"
  ON public.planes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = creator_id OR creator_id IS NULL);

DROP POLICY IF EXISTS "Creador o miembros pueden actualizar el plan" ON public.planes;
CREATE POLICY "Creador o miembros pueden actualizar el plan"
  ON public.planes FOR UPDATE
  TO authenticated
  USING (auth.uid() = creator_id OR EXISTS (
    SELECT 1 FROM public.miembros_plan WHERE plan_id = planes.id AND user_id = auth.uid()
  ));

DROP POLICY IF EXISTS "Solo el creador puede eliminar el plan" ON public.planes;
CREATE POLICY "Solo el creador puede eliminar el plan"
  ON public.planes FOR DELETE
  TO authenticated
  USING (auth.uid() = creator_id);

-- Políticas MIEMBROS_PLAN
DROP POLICY IF EXISTS "Ver miembros de planes" ON public.miembros_plan;
CREATE POLICY "Ver miembros de planes"
  ON public.miembros_plan FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Agregar miembros a un plan" ON public.miembros_plan;
CREATE POLICY "Agregar miembros a un plan"
  ON public.miembros_plan FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Miembro puede actualizar su propio estado" ON public.miembros_plan;
CREATE POLICY "Miembro puede actualizar su propio estado"
  ON public.miembros_plan FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Políticas ENCUESTAS
DROP POLICY IF EXISTS "Ver encuestas de planes" ON public.encuestas;
CREATE POLICY "Ver encuestas de planes"
  ON public.encuestas FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Crear encuestas" ON public.encuestas;
CREATE POLICY "Crear encuestas"
  ON public.encuestas FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Actualizar encuestas" ON public.encuestas;
CREATE POLICY "Actualizar encuestas"
  ON public.encuestas FOR UPDATE
  TO authenticated
  USING (true);

-- Políticas OPCIONES_ENCUESTA
DROP POLICY IF EXISTS "Ver opciones de encuestas" ON public.opciones_encuesta;
CREATE POLICY "Ver opciones de encuestas"
  ON public.opciones_encuesta FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Crear opciones de encuestas" ON public.opciones_encuesta;
CREATE POLICY "Crear opciones de encuestas"
  ON public.opciones_encuesta FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Políticas VOTOS_ENCUESTA
DROP POLICY IF EXISTS "Ver votos de encuestas" ON public.votos_encuesta;
CREATE POLICY "Ver votos de encuestas"
  ON public.votos_encuesta FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Votar si encuesta está abierta" ON public.votos_encuesta;
CREATE POLICY "Votar si encuesta está abierta"
  ON public.votos_encuesta FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Retirar propio voto" ON public.votos_encuesta;
CREATE POLICY "Retirar propio voto"
  ON public.votos_encuesta FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Políticas VACAS y APORTES
DROP POLICY IF EXISTS "Ver fondos de vacas" ON public.vacas;
CREATE POLICY "Ver fondos de vacas"
  ON public.vacas FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Crear vaca para un plan" ON public.vacas;
CREATE POLICY "Crear vaca para un plan"
  ON public.vacas FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Registrar aportes a vacas" ON public.aportes_vaca;
CREATE POLICY "Registrar aportes a vacas"
  ON public.aportes_vaca FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Ver aportes a vacas" ON public.aportes_vaca;
CREATE POLICY "Ver aportes a vacas"
  ON public.aportes_vaca FOR SELECT
  TO authenticated
  USING (true);

-- ==============================================================================
-- 5. BUCKETS DE STORAGE (Portadas de planes y Avatares)
-- ==============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('portadas-planes', 'portadas-planes', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatares', 'avatares', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Portadas públicas lectura" ON storage.objects;
CREATE POLICY "Portadas públicas lectura"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id IN ('portadas-planes', 'avatares'));

DROP POLICY IF EXISTS "Usuarios autenticados suben portadas" ON storage.objects;
CREATE POLICY "Usuarios autenticados suben portadas"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id IN ('portadas-planes', 'avatares'));

DROP POLICY IF EXISTS "Usuarios actualizan sus imágenes de storage" ON storage.objects;
CREATE POLICY "Usuarios actualizan sus imágenes de storage"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id IN ('portadas-planes', 'avatares'));

-- ==============================================================================
-- 6. PUBLICACIÓN SUPABASE REALTIME
-- ==============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'planes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.planes;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'encuestas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.encuestas;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'opciones_encuesta'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.opciones_encuesta;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'votos_encuesta'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.votos_encuesta;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'amistades'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.amistades;
  END IF;
END $$;

-- ==============================================================================
-- 7. SINCRONIZACIÓN DE USUARIOS EXISTENTES (auth.users -> public.perfiles)
-- ==============================================================================
INSERT INTO public.perfiles (id, full_name, username, avatar_url, role, streak)
SELECT 
  id,
  COALESCE(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', split_part(email, '@', 1)),
  COALESCE(raw_user_meta_data->>'user_name', split_part(email, '@', 1) || '_' || substr(id::text, 1, 4)),
  COALESCE(raw_user_meta_data->>'avatar_url', raw_user_meta_data->>'picture', NULL),
  'user',
  1
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 8. CARGA DE CATÁLOGOS MAESTROS (CATEGORÍAS, FILTROS Y LUGARES)
-- ==============================================================================

-- A) CATEGORÍAS
INSERT INTO public.categorias_plan (id, nombre, descripcion, icono, portadas_preset)
VALUES
(
  'viaje',
  'Viaje o Paseo',
  'Paseos a la playa, finca o carretera con el parche.',
  'Palmtree',
  ARRAY[
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80'
  ]
),
(
  'fiesta',
  'Rumba & Fiesta',
  'Discotecas, bares, chivas y noches de fiesta.',
  'PartyPopper',
  ARRAY[
    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&q=80'
  ]
),
(
  'concierto',
  'Concierto / Festival',
  'Festivales de música, toques y recitales en vivo.',
  'Music',
  ARRAY[
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=80'
  ]
),
(
  'comida',
  'Comida & Gastrobar',
  'Almuerzos, cenas, asados y catas con amigos.',
  'Utensils',
  ARRAY[
    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1200&q=80'
  ]
),
(
  'deporte',
  'Deporte & Aventura',
  'Partidos de fútbol, senderismo, ciclovía o kayak.',
  'Activity',
  ARRAY[
    'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1517649763962-0c623266ddc0?auto=format&fit=crop&w=1200&q=80'
  ]
),
(
  'chill',
  'Plan Tranqui / Chill',
  'Tardes de café, juegos de mesa, cine o picnic en el parque.',
  'Coffee',
  ARRAY[
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&w=1200&q=80'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  icono = EXCLUDED.icono,
  portadas_preset = EXCLUDED.portadas_preset;

-- B) FILTROS
INSERT INTO public.catalogo_filtros (tipo, clave, etiqueta, descripcion)
VALUES
-- Edad
('edad', 'todos', 'Para todas las edades', 'Plan apto para niños, jóvenes y adultos.'),
('edad', '+18', 'Solo mayores de 18 (+18)', 'Plan con consumo de licor o ingreso exclusivo para adultos.'),
('edad', 'familiar', 'Plan Familiar', 'Ambiente tranquilo pensado para la familia.'),

-- Accesibilidad
('accesibilidad', 'ninguna', 'Estándar / Ninguna', 'Sin requerimientos especiales de movilidad.'),
('accesibilidad', 'silla_ruedas', 'Rampa / Silla de ruedas', 'Espacio con accesibilidad física y rampas.'),
('accesibilidad', 'baja_movilidad', 'Baja movilidad', 'Espacio con pocos desplazamientos a pie o escaleras.'),
('accesibilidad', 'pet_friendly', 'Pet Friendly 🐾', 'Se admiten mascotas en el lugar.'),

-- Género
('genero', 'mixto', 'Parche Mixto', 'Abierto a todos los géneros sin distinción.'),
('genero', 'solo_mujeres', 'Solo Chicas / Mujeres', 'Plan exclusivo para amigas y mujeres.'),
('genero', 'solo_hombres', 'Solo Hombres', 'Plan exclusivo para parceros.'),

-- Círculos
('circulo', 'todos', 'Todos los amigos', 'Ver todos los contactos sin distinción de cercanía.'),
('circulo', 'intimo', 'Círculo Íntimo', 'Amigos de máxima confianza con los que sales siempre.'),
('circulo', 'cercano', 'Círculo Cercano', 'Amigos frecuentes de la universidad, trabajo o barrio.'),
('circulo', 'comunidad', 'Comunidad / Parche Amplio', 'Conocidos, parches masivos o grupos grandes.')
ON CONFLICT (tipo, clave) DO UPDATE SET
  etiqueta = EXCLUDED.etiqueta,
  descripcion = EXCLUDED.descripcion;

-- C) LUGARES SUGERIDOS
INSERT INTO public.lugares_sugeridos (nombre, sublabel, categoria, foto_url)
VALUES
(
  'Cabaña Vista al Mar (Rodadero)',
  'Santa Marta, Magdalena',
  'viaje',
  'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?auto=format&fit=crop&w=600&q=80'
),
(
  'Glamping Bosque de la Niebla',
  'Guatavita, Cundinamarca',
  'chill',
  'https://images.unsplash.com/photo-1510312305653-8ed496efae75?auto=format&fit=crop&w=600&q=80'
),
(
  'Terraza Rooftop 93',
  'Parque de la 93, Bogotá',
  'fiesta',
  'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=600&q=80'
),
(
  'Finca El Paraíso con Piscina',
  'Girardot, Cundinamarca',
  'viaje',
  'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=600&q=80'
),
(
  'Restaurante Campestre La Hacienda',
  'Rionegro, Antioquia',
  'comida',
  'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80'
),
(
  'Parque Central / Senderismo',
  'Parque Arví, Medellín',
  'deporte',
  'https://images.unsplash.com/photo-1517649763962-0c623266ddc0?auto=format&fit=crop&w=600&q=80'
)
ON CONFLICT DO NOTHING;
