-- ==============================================================================
-- 🚀 APPARCHAR - CATÁLOGO DE FILTROS, CATEGORÍAS Y LUGARES SUGERIDOS (SQL)
-- Este script crea las tablas de catálogo e inserta todos los datos maestros
-- (filtros, presets de fotos y lugares de muestra) SIN insertar ningún plan falso.
-- ==============================================================================

-- 1. TABLA DE CATEGORÍAS CON SUS PRESETS DE PORTADAS
CREATE TABLE IF NOT EXISTS public.categorias_plan (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  icono TEXT,
  portadas_preset TEXT[] NOT NULL DEFAULT '{}'
);

-- Habilitar lectura pública de categorías
ALTER TABLE public.categorias_plan ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura pública de categorías" ON public.categorias_plan;
CREATE POLICY "Lectura pública de categorías"
  ON public.categorias_plan FOR SELECT
  TO public
  USING (true);

-- 2. TABLA DE FILTROS DE AUDIENCIA Y CÍRCULOS DEL SISTEMA
CREATE TABLE IF NOT EXISTS public.catalogo_filtros (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo TEXT NOT NULL CHECK (tipo IN ('edad', 'accesibilidad', 'genero', 'circulo')),
  clave TEXT NOT NULL,
  etiqueta TEXT NOT NULL,
  descripcion TEXT,
  UNIQUE(tipo, clave)
);

-- Habilitar lectura pública de filtros
ALTER TABLE public.catalogo_filtros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura pública de filtros" ON public.catalogo_filtros;
CREATE POLICY "Lectura pública de filtros"
  ON public.catalogo_filtros FOR SELECT
  TO public
  USING (true);

-- 3. TABLA DE LUGARES SUGERIDOS CON FOTOS PARA ENCUESTAS
CREATE TABLE IF NOT EXISTS public.lugares_sugeridos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  sublabel TEXT,
  categoria TEXT REFERENCES public.categorias_plan(id) ON DELETE SET NULL,
  foto_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Habilitar lectura pública de lugares
ALTER TABLE public.lugares_sugeridos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Lectura pública de lugares" ON public.lugares_sugeridos;
CREATE POLICY "Lectura pública de lugares"
  ON public.lugares_sugeridos FOR SELECT
  TO public
  USING (true);

-- ==============================================================================
-- 4. INSERT DE CATEGORÍAS Y PRESETS DE FOTOS (COVER_PRESETS)
-- ==============================================================================
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

-- ==============================================================================
-- 5. INSERT DE FILTROS DEL SISTEMA (EDAD, ACCESIBILIDAD, GÉNERO, CÍRCULOS)
-- ==============================================================================
INSERT INTO public.catalogo_filtros (tipo, clave, etiqueta, descripcion)
VALUES
-- Filtros de Edad
('edad', 'todos', 'Para todas las edades', 'Plan apto para niños, jóvenes y adultos.'),
('edad', '+18', 'Solo mayores de 18 (+18)', 'Plan con consumo de licor o ingreso exclusivo para adultos.'),
('edad', 'familiar', 'Plan Familiar', 'Ambiente tranquilo pensado para la familia.'),

-- Filtros de Accesibilidad
('accesibilidad', 'ninguna', 'Estándar / Ninguna', 'Sin requerimientos especiales de movilidad.'),
('accesibilidad', 'silla_ruedas', 'Rampa / Silla de ruedas', 'Espacio con accesibilidad física y rampas.'),
('accesibilidad', 'baja_movilidad', 'Baja movilidad', 'Espacio con pocos desplazamientos a pie o escaleras.'),
('accesibilidad', 'pet_friendly', 'Pet Friendly 🐾', 'Se admiten mascotas en el lugar.'),

-- Filtros de Género
('genero', 'mixto', 'Parche Mixto', 'Abierto a todos los géneros sin distinción.'),
('genero', 'solo_mujeres', 'Solo Chicas / Mujeres', 'Plan exclusivo para amigas y mujeres.'),
('genero', 'solo_hombres', 'Solo Hombres', 'Plan exclusivo para parceros.'),

-- Círculos de Amistad
('circulo', 'todos', 'Todos los amigos', 'Ver todos los contactos sin distinción de cercanía.'),
('circulo', 'intimo', 'Círculo Íntimo', 'Amigos de máxima confianza con los que sales siempre.'),
('circulo', 'cercano', 'Círculo Cercano', 'Amigos frecuentes de la universidad, trabajo o barrio.'),
('circulo', 'comunidad', 'Comunidad / Parche Amplio', 'Conocidos, parches masivos o grupos grandes.')
ON CONFLICT (tipo, clave) DO UPDATE SET
  etiqueta = EXCLUDED.etiqueta,
  descripcion = EXCLUDED.descripcion;

-- ==============================================================================
-- 6. INSERT DE LUGARES SUGERIDOS (LOCATION_PRESETS) CON FOTOS REALES
-- ==============================================================================
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
);
