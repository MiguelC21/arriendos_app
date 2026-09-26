# Arriendos App 🏠🏢

Plataforma profesional, moderna y **Local-First** para la gestión integral de inmuebles, apartamentos, contratos de arrendamiento y control de pagos. Compatible de forma nativa con **Móvil (Android / iOS)** y **Web (Desktop / Navegadores)**.

---

## ✨ Características Principales

- **Arquitectura Local-First (Offline-First)**: Funcionalidad completa sin conexión a internet. Los datos se guardan al instante en el dispositivo (`hive_ce` / IndexedDB) y se sincronizan automáticamente con Supabase al recuperar la red.
- **Doble Entorno (Local vs Producción)**: Entorno de pruebas completamente aislado en Docker con Supabase CLI (costo $0) y conexión en vivo a Supabase Cloud en producción.
- **Soporte Multiplataforma**:
  - **Móvil**: Interfaz optimizada con controles táctiles y accesos directos a WhatsApp.
  - **Web / Desktop**: Layout responsivo adaptativo con barra lateral (*Sidebar*) y cuadrícula inteligente de inmuebles.
- **Gestión Financiera**: Control de pagos del mes, cálculo automático de deuda acumulada, registro de abonos y pagos en cascada.
- **UI/UX Premium**: Tema oscuro profundo (*Slate 950*), tarjetas con diseño tipo cristal, badges luminosos de estado y monitoreo de conectividad en tiempo real.

---

## 📋 Requisitos Previos

1. **Flutter SDK**: Versión 3.20 o superior instalada ([Guía de instalación](https://docs.flutter.dev/get-started/install)).
2. **Docker Desktop**: Necesario para ejecutar la base de datos local de Supabase ([Descargar Docker](https://www.docker.com/products/docker-desktop/)).
3. **Supabase CLI**: Instalado en el sistema para la administración local ([Instrucciones CLI](https://supabase.com/docs/guides/cli)).

---

## 🐳 Gestión de Base de Datos: Local vs Producción

La aplicación cuenta con dos entornos de base de datos independientes para proteger tus datos reales:

| Entorno | Ubicación | URL por defecto | Descripción |
| :--- | :--- | :--- | :--- |
| **Local (Pruebas)** | Tu máquina (Docker) | `http://127.0.0.1:54321` | Base de datos aislada para pruebas sin conexión ni riesgo a producción. Costo $0. |
| **Producción (Cloud)** | Supabase Cloud | `https://npjpxjrrdxnplpxatxpb.supabase.co` | Base de datos oficial con tus datos en vivo. |

### Comandos de Supabase Local y Makefile

Desde la raíz del proyecto puedes utilizar los atajos del `Makefile` o los comandos directos de Supabase CLI:

```bash
# Iniciar contenedores locales (Postgres, Auth, Storage, etc.)
make start       # o: supabase start / npx supabase start

# Detener contenedores locales
make stop        # o: supabase stop / npx supabase stop

# Ver el estado, puertos y credenciales locales
make status      # o: supabase status / npx supabase status
```

> **Panel Web Local (Supabase Studio)**:  
> Al iniciar Supabase, puedes acceder al panel de administración gráfico local en tu navegador:  
> 👉 [http://127.0.0.1:54323](http://127.0.0.1:54323)

---

### 🌿 Sembrado de Datos de Prueba (Seed Data)

El proyecto cuenta con un script de datos de prueba en [`supabase/seed.sql`](supabase/seed.sql) que incluye inmuebles de prueba (*Edificio Santa Fe*, *Torres del Parque*), apartamentos y oficinas con valores base para simular pagos y contratos.

Para poblar o restablecer la base de datos local con estos datos de prueba:

#### Opción A: Usando Make (Recomendado)
```bash
make seed
```
*(O si deseas reiniciar la base local desde cero aplicando migraciones y siembra completa:* `make reset`*)*.

#### Opción B: Usando Supabase CLI directamente
```bash
# Si tienes Supabase CLI instalado:
supabase db reset

# O ejecutándolo directamente con npx (sin instalar nada adicional):
npx supabase db reset
```

> [!NOTE]
> * **100% Seguro y Aislado**: El comando `make seed` actúa **exclusivamente** sobre tu contenedor local de Docker (`http://127.0.0.1:54321`). Nunca afectará ni modificará tus datos reales en Supabase Cloud.
> * **Verificación Visual**: Puedes entrar a [http://127.0.0.1:54323](http://127.0.0.1:54323) (*Table Editor*) para ver los datos sembrados en PostgreSQL.
> * **Sincronización en la App**: Al abrir la aplicación en modo Local (o al entrar a **Ajustes** y presionar *"Sincronizar ahora con base local"*), la app descargará y reflejará los datos sembrados en tu pantalla de inmediato.

---

## 🚀 Cómo Iniciar la Aplicación

Puedes iniciar la app seleccionando el objetivo (**Móvil** o **Web**) y el entorno de base de datos (**Local** o **Producción**).

### 1. Modo Móvil (Android / iOS)

Asegúrate de tener un emulador encendido o un dispositivo físico conectado:

#### A. Móvil con Base de Datos Local (Pruebas)
```bash
flutter run --dart-define=ENV=local
```
*(Nota: En el emulador de Android, la app detecta automáticamente la IP `10.0.2.2:54321` para conectarse a tu Docker local sin necesidad de configuraciones adicionales)*.

#### B. Móvil con Base de Datos de Producción (Cloud)
```bash
flutter run --dart-define=ENV=prod
```

---

### 2. Modo Web (Chrome / Edge / Navegadores)

Para abrir la versión web adaptada a pantallas de escritorio con barra lateral:

#### A. Web con Base de Datos Local (Pruebas)
```bash
flutter run -d chrome --dart-define=ENV=local
```

#### B. Web con Base de Datos de Producción (Cloud)
```bash
flutter run -d chrome --dart-define=ENV=prod
```

#### C. Compilación para Producción Web (Build)
Para generar los archivos estáticos listos para desplegar en cualquier hosting (Vercel, Netlify, Firebase Hosting, Cloudflare Pages):
```bash
flutter build web
```
*Los archivos compilados quedarán generados en la carpeta `build/web/`.*

---

## 🔀 Alternar Entornos en Caliente (Dentro de la App)

No es obligatorio recompilar para cambiar de entorno. Puedes alternar la base de datos directamente desde la interfaz gráfica:

1. Inicia la aplicación.
2. Ve a la pantalla de **Ajustes** (icono de engranaje ⚙️ en el AppBar o en la barra lateral en Web).
3. En la sección **"Entorno de la Aplicación"**, selecciona:
   - ☁️ **Producción (Supabase Cloud)**
   - 🐳 **Pruebas en Local (Docker / CLI)**
4. La selección se guardará en el almacenamiento del dispositivo y se aplicará inmediatamente a los servicios y consultas.

---

## 🔄 Sincronización y Modo Offline (Local-First)

En la parte superior de la pantalla verás un **chip de estado de conexión interactivo**:

- 🟢 **En línea**: Conectado a Supabase Producción y sincronizado.
- 🟡 **Local (Dev)**: Conectado a tu contenedor Docker local.
- 🟡 **Sincronizando...**: Subiendo o descargando datos con la nube.
- 🔴 **Sin conexión (X pendientes)**: Modo offline activado. Los datos se guardan de inmediato en local y se subirán automáticamente en cuanto regrese la conexión.

*Tip: Puedes tocar el chip de estado en cualquier momento para forzar una sincronización manual inmediata.*

---

## 🧪 Pruebas de Calidad

Para verificar la integridad del código y las pruebas unitarias:

```bash
# Analizar código estático (debe reportar 0 errores)
flutter analyze

# Ejecutar suite de pruebas unitarias
flutter test
```

---

© 2026 Arriendos App - Gestión Inmobiliaria Profesional y Local-First.
