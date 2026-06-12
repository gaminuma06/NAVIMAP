# Plan de Preparación para Producción - NAVIMAP

Este documento detalla todos los pasos necesarios para migrar el backend de Firebase y la facturación de Google Play Store desde el "Modo de Prueba" (o sandbox de desarrollo) a un entorno de **Producción** completamente seguro y comercial.

---

## 1. Reglas de Seguridad de Firestore (Crítico)

En el modo de prueba, Firebase crea reglas que permiten a cualquiera leer y escribir sin autenticación durante 30 días. Para producción, debes asegurar la base de datos reemplazando las reglas en la pestaña **Rules** de Firestore Database en el Firebase Console.

### Reglas Propuestas para NAVIMAP
Copia y pega el siguiente código en tu Firebase Web Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Reglas para la colección de usuarios
    match /users/{userId} {
      // Un usuario autenticado solo puede leer y modificar su propio documento de perfil
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Reglas para los códigos de acceso corporativos (HLG y PRO)
    match /accessCodes/{codeId} {
      // Cualquier usuario autenticado puede leer/validar si un código existe
      allow read: if request.auth != null;
      
      // Permitir la actualización del código solo si:
      // 1. El usuario está autenticado.
      // 2. El campo 'usedBy' se actualiza con el UID del usuario que hace la petición.
      // 3. El código no estaba previamente asignado a otro UID (o es el del mismo usuario).
      allow update: if request.auth != null 
                    && request.resource.data.usedBy == request.auth.uid
                    && (resource.data.usedBy == null || resource.data.usedBy == request.auth.uid);
                    
      // Los usuarios no pueden crear ni borrar códigos de acceso desde la app (solo administrador)
      allow create, delete: if false;
    }
  }
}
```

---

## 2. Configuración de Firebase Authentication

Para que el inicio de sesión funcione correctamente en producción:

### A. Proveedores de Inicio de Sesión
Verifica en la sección **Authentication > Sign-in method** del Firebase Console que estén activos:
1. **Correo electrónico/contraseña (Email/Password)**.
2. **Google (Google Sign-In)**.

### B. OAuth y SHA-1 / SHA-256 en Android (Muy Importante)
Google Sign-In y Firebase fallarán en la app instalada desde la Google Play Store si no agregas las firmas del almacén de claves (Keystore) de producción:
1. Genera las firmas SHA-1 y SHA-256 de tu clave de producción (o utiliza la firma de Play App Signing provista por Google Play Console).
2. Ve a **Project Settings (Ajustes de Proyecto)** en Firebase Console.
3. Desplázate hacia abajo hasta la app de Android y agrega los certificados SHA-1 y SHA-256.
4. Descarga el nuevo archivo `google-services.json` y reemplázalo en `android/app/google-services.json`.
5. Si usas Google Sign-In, asegúrate de configurar la **Pantalla de Consentimiento de OAuth** en el Google Cloud Console (asociado a tu proyecto de Firebase) en modo **Externo** y publica la pantalla para que cualquier usuario pueda iniciar sesión.

---

## 3. Google Play Console y Compras Integradas (Facturación)

Actualmente, el sistema de cobros utiliza el ID de suscripción `navimap_pro_monthly`. Para lanzar comercialmente:

1. **Crear el Producto de Suscripción:**
   - En Google Play Console, ve a **Monetizar > Productos > Suscripciones**.
   - Haz clic en **Crear suscripción**.
   - Define el ID de producto exactamente como: `navimap_pro_monthly`.
   - Configura los precios, periodos de gracia y periodos de facturación mensual. Asegúrate de activar la suscripción.

2. **Configurar Licencias y Pruebas Cerradas:**
   - Mientras subes el primer APK/AAB a producción, puedes probar el flujo de pagos agregando tu cuenta de correo electrónico a la sección **Configuración de licencias** de Google Play Console. Esto te permitirá simular compras reales con cobros de prueba antes de cobrar a clientes.

3. **Vincular Google Play con Firebase:**
   - En Firebase Console, ve a **Project Settings > Integrations**.
   - Busca **Google Play** y haz clic en **Link**. Esto permite que Firebase reciba automáticamente los eventos de compra e informe el estado de las suscripciones en tiempo real.

---

## 4. Gestión Administrativa de Códigos (Hacienda La Gloria y Pro)

Como las reglas impiden crear códigos desde la aplicación, debes registrar los códigos directamente en la base de datos de Firestore (usando Firebase Console o un script/panel administrativo).

### Estructura de un Documento en `accessCodes`
Para crear un nuevo código utilizable, crea un documento en la colección `accessCodes` con la clave del código como ID del documento (ej. `NAVIMAP-HLG-2026`) y la siguiente estructura:

* **ID del Documento:** `NAVIMAP-HLG-2026`
* **Campos:**
  * `active`: `true` (Boolean)
  * `plan`: `hlg` o `pro` (String)
  * `usedBy`: `null` (dejar vacío o no crear el campo hasta que un usuario lo registre)

Cuando el usuario lo active desde la aplicación, el campo `usedBy` cambiará automáticamente a su UID y se creará su perfil en la colección `users`, desbloqueando sus herramientas al instante.
