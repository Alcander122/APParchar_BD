-- ==============================================================================
-- 🚀 APPARCHAR - ESQUEMA DE BASE DE DATOS SUPABASE EN ESPAÑOL (COMPLETO E IDEMPOTENTE)
-- Tablas en Español: perfiles, amistades, planes, miembros_plan, encuestas,
-- opciones_encuesta, votos_encuesta, vacas, aportes_vaca.
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

-- 2. LIMPIEZA DE TABLAS PREVIAS (Para poder ejecutar todo de una sin conflictos)
DROP TABLE IF EXISTS public.amistades CASCADE;
DROP TABLE IF EXISTS public.aportes_vaca CASCADE;
DROP TABLE IF EXISTS public.vacas CASCADE;
DROP TABLE IF EXISTS public.votos_encuesta CASCADE;
DROP TABLE IF EXISTS public.opciones_encuesta CASCADE;
DROP TABLE IF EXISTS public.encuestas CASCADE;
DROP TABLE IF EXISTS public.miembros_plan CASCADE;
DROP TABLE IF EXISTS public.planes CASCADE;
DROP TABLE IF EXISTS public.perfiles CASCADE;

-- Limpieza de versiones previas en inglés si existían
DROP TABLE IF EXISTS public.poll_votes CASCADE;
DROP TABLE IF EXISTS public.poll_options CASCADE;
DROP TABLE IF EXISTS public.polls CASCADE;
DROP TABLE IF EXISTS public.savings_contributions CASCADE;
DROP TABLE IF EXISTS public.savings CASCADE;
DROP TABLE IF EXISTS public.plan_members CASCADE;
DROP TABLE IF EXISTS public.plans CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- ==============================================================================
-- 3. TABLA PERFILES (Identidad del usuario vinculada a auth.users)
-- ==============================================================================
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

-- ==============================================================================
-- 4. TABLA AMISTADES (Relaciones y círculos entre usuarios)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.amistades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  amigo_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  circulo TEXT NOT NULL DEFAULT 'cercano' CHECK (circulo IN ('intimo', 'cercano', 'comunidad')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(user_id, amigo_id)
);

-- ==============================================================================
-- 5. TABLA PLANES (Parches)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.planes (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL CHECK (category IN ('viaje', 'fiesta', 'concierto', 'comida', 'deporte', 'chill')),
  cover_image TEXT,
  status TEXT NOT NULL DEFAULT 'voting' CHECK (status IN ('voting', 'confirmed', 'history')),
  date TEXT DEFAULT 'Por definir',
  location TEXT DEFAULT 'Por definir',
  budget_estimated NUMERIC DEFAULT 0,
  
  -- Filtros de audiencia
  age_filter TEXT NOT NULL DEFAULT '+18' CHECK (age_filter IN ('todos', '+18', 'familiar')),
  accessibility_filter TEXT NOT NULL DEFAULT 'ninguna' CHECK (accessibility_filter IN ('ninguna', 'silla_ruedas', 'baja_movilidad', 'pet_friendly')),
  gender_filter TEXT NOT NULL DEFAULT 'mixto' CHECK (gender_filter IN ('mixto', 'solo_mujeres', 'solo_hombres')),
  
  creator_id UUID REFERENCES public.perfiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ==============================================================================
-- 6. TABLA MIEMBROS_PLAN (Invitados y Miembros del Parche)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.miembros_plan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id TEXT NOT NULL REFERENCES public.planes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'parcheador' CHECK (role IN ('organizador', 'tesorero', 'parcheador', 'invitado')),
  status TEXT NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'accepted', 'declined')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(plan_id, user_id)
);

-- ==============================================================================
-- 7. TABLA ENCUESTAS (Encuestas y Temporizador del Plan)
-- ==============================================================================
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

-- ==============================================================================
-- 8. TABLA OPCIONES_ENCUESTA (Opciones dinámicas de Fechas y Lugares)
-- ==============================================================================
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

-- ==============================================================================
-- 9. TABLA VOTOS_ENCUESTA (Votos emitidos por los usuarios)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.votos_encuesta (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.encuestas(id) ON DELETE CASCADE,
  option_id UUID NOT NULL REFERENCES public.opciones_encuesta(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE(option_id, user_id)
);

-- ==============================================================================
-- 10. TABLA VACAS (La Vaca / Finanzas del Parche)
-- ==============================================================================
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
-- 11. TRIGGERS Y FUNCIONES AUTOMÁTICAS
-- ==============================================================================

-- A) Trigger para crear perfil automáticamente al registrarse (Email o Google OAuth)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfiles (id, full_name, username, avatar_url, role, streak)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'Parcheador'),
    COALESCE(NEW.raw_user_meta_data->>'user_name', split_part(NEW.email, '@', 1)),
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

-- B) Trigger para updated_at automático
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

-- C) Trigger para actualizar monto acumulado en vacas al hacer aportes
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
-- 12. SEGURIDAD: ROW LEVEL SECURITY (RLS)
-- ==============================================================================

ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amistades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planes ENABLE ROW LEVEL SECURITY;
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
  WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM public.encuestas
      WHERE id = poll_id AND is_closed = FALSE AND expires_at > now()
    )
  );

DROP POLICY IF EXISTS "Retirar propio voto si encuesta está abierta" ON public.votos_encuesta;
CREATE POLICY "Retirar propio voto si encuesta está abierta"
  ON public.votos_encuesta FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM public.encuestas
      WHERE id = poll_id AND is_closed = FALSE AND expires_at > now()
    )
  );

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
-- 13. BUCKETS DE STORAGE (Portadas de planes y Avatares)
-- ==============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('portadas-planes', 'portadas-planes', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatares', 'avatares', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Políticas de Storage para portadas-planes
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
-- 14. PUBLICACIÓN SUPABASE REALTIME
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
-- 15. CIERRE AUTOMÁTICO DE ENCUESTAS & OPCIÓN GANADORA (pg_cron / Función)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.cerrar_encuestas_vencidas()
RETURNS void AS $$
DECLARE
  poll_record RECORD;
  best_date_id UUID;
  best_location_id UUID;
  winning_date_label TEXT;
  winning_location_label TEXT;
BEGIN
  FOR poll_record IN 
    SELECT p.id, p.plan_id
    FROM public.encuestas p
    WHERE p.is_closed = FALSE AND p.expires_at <= timezone('utc'::text, now())
  LOOP
    -- Calcular opción de fecha ganadora
    SELECT po.id, po.label INTO best_date_id, winning_date_label
    FROM public.opciones_encuesta po
    LEFT JOIN public.votos_encuesta pv ON pv.option_id = po.id
    WHERE po.poll_id = poll_record.id AND po.type = 'date'
    GROUP BY po.id, po.label
    ORDER BY COUNT(pv.id) DESC, po.created_at ASC
    LIMIT 1;

    -- Calcular opción de lugar ganador
    SELECT po.id, po.label INTO best_location_id, winning_location_label
    FROM public.opciones_encuesta po
    LEFT JOIN public.votos_encuesta pv ON pv.option_id = po.id
    WHERE po.poll_id = poll_record.id AND po.type = 'location'
    GROUP BY po.id, po.label
    ORDER BY COUNT(pv.id) DESC, po.created_at ASC
    LIMIT 1;

    -- Cerrar la encuesta
    UPDATE public.encuestas
    SET is_closed = TRUE,
        winning_date_option_id = best_date_id,
        winning_location_option_id = best_location_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = poll_record.id;

    -- Actualizar el Plan a 'confirmed' y colocar fecha y lugar definitivos
    UPDATE public.planes
    SET status = 'confirmed',
        date = COALESCE(winning_date_label, date),
        location = COALESCE(winning_location_label, location),
        updated_at = timezone('utc'::text, now())
    WHERE id = poll_record.plan_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.close_expired_polls()
RETURNS void AS $$
BEGIN
  PERFORM public.cerrar_encuestas_vencidas();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Programar ejecución cada minuto con pg_cron si está habilitado
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      PERFORM cron.unschedule('cerrar-encuestas-job');
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    BEGIN
      PERFORM cron.schedule('cerrar-encuestas-job', '* * * * *', 'SELECT public.cerrar_encuestas_vencidas();');
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;
