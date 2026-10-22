# 🚀 APParchar - Repositorio de Base de Datos y Analítica (Supabase / PostgreSQL)

Este repositorio contiene el esquema oficial, migraciones, catálogos y políticas de seguridad (RLS) para la plataforma **APParchar**. Está diseñado para el equipo de datos, analistas y administración de la base de datos en Supabase.

---

## 📁 Estructura del Repositorio

`
APParchar_BD/
├── README.md
└── supabase/
    ├── setup_completo.sql          # Script unificado e idempotente con todo el esquema
    ├── schema.sql                  # Definición de tablas, llaves foráneas y RLS
    ├── presets_and_filters.sql     # Catálogo de categorías, filtros maestros y lugares
    ├── seed.sql                    # Datos de prueba opcionales
    └── migrations/
        └── 20261022000000_setup_completo.sql  # Migración automática para integración con GitHub
`

---

## 🗄️ Diccionario de Datos (Tablas en Español)

| Tabla | Descripción | Llaves / Relaciones |
| :--- | :--- | :--- |
| **perfiles** | Datos de cuenta, rol (user/dmin), avatar y racha de asistencia. | id REFERENCES auth.users(id) |
| **mistades** | Relación entre dos usuarios y su círculo (intimo, cercano, comunidad). | user_id y migo_id hacia perfiles(id) |
| **categorias_plan** | Catálogo oficial de categorías (Viaje, Rumba, Concierto, Comida, etc.) y presets de portadas. | id (Texto identificador) |
| **catalogo_filtros** | Opciones dinámicas de filtros (edad, accesibilidad, género y círculos de amistad). | id UUID, 	ipo, clave, etiqueta |
| **planes** | Información central del parche (título, descripción, fecha, lugar, filtros y creador). | creator_id REFERENCES perfiles(id) |
| **lugares_sugeridos** | Lugares recomendados con fotos reales de Unsplash para creación de encuestas. | categoria REFERENCES categorias_plan(id) |
| **miembros_plan** | Participantes invitados a un plan y su estado (invited, ccepted, declined). | plan_id y user_id |
| **encuestas** | Encuesta de votación colaborativa y temporizador (12h, 24h, 48h, 72h). | plan_id REFERENCES planes(id) |
| **opciones_encuesta** | Opciones de fecha y lugar propuestas por los amigos. | poll_id REFERENCES encuestas(id) |
| **otos_encuesta** | Votos emitidos por cada participante sobre fechas y lugares. | option_id y user_id |
| **acas** | Recaudación colaborativa del parche (monto meta y monto actual). | plan_id REFERENCES planes(id) |
| **portes_vaca** | Registro de aportes económicos realizados por cada usuario. | aca_id y user_id |

---

## ⚙️ Cómo desplegar o actualizar en Supabase

### Opción 1: Automático vía GitHub (CI/CD)
Al hacer merge de cambios a la rama main en este repositorio, la integración de Supabase ejecuta automáticamente los archivos dentro de supabase/migrations/.

### Opción 2: Manual vía SQL Editor de Supabase
1. Abre tu proyecto en [Supabase Dashboard](https://supabase.com/dashboard).
2. Ve a la sección **SQL Editor**.
3. Copia y pega el contenido de supabase/setup_completo.sql.
4. Haz clic en **Run**. El script es idempotente (IF NOT EXISTS y ON CONFLICT DO UPDATE), por lo que no borrará ni duplicará datos existentes.

---

## 🔒 Seguridad (Row Level Security - RLS)
Todas las tablas cuentan con políticas de seguridad RLS activas:
- **Lectura pública**: Catálogos (categorias_plan, catalogo_filtros, lugares_sugeridos) e invitaciones públicas a planes.
- **Escritura protegida**: Los usuarios autenticados solo pueden modificar sus propios registros, votar en encuestas abiertas y registrar aportes a su nombre.
