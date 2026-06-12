# Guía Completa de Configuración de Firebase para Producción

Esta guía está redactada paso a paso para que puedas configurar la base de datos de **Firebase** y crear tus propios códigos de acceso únicos (de un solo uso) sin necesidad de saber programar en la consola, manteniendo la compatibilidad para hacer pruebas locales en `localhost:5000` o en emuladores Android.

---

## 1. Enlace a la Consola y Navegación

Toda la administración de tu backend se realiza desde la Consola de Firebase:
* **Enlace principal:** [https://console.firebase.google.com/](https://console.firebase.google.com/)

Al ingresar e iniciar sesión con tu cuenta de Google, verás tu proyecto llamado **NAVIMAP** (o el ID asociado a tu base de datos). Haz clic sobre él para abrir el panel de control.

---

## 2. Configurar las Reglas de la Base de Datos (Seguridad)

Para proteger tu información y que la base de datos no expire (quitando el modo de prueba síncrono):

1. En el menú lateral izquierdo de la consola de Firebase, haz clic en **Firestore Database** (debajo de la sección *Build* o *Construcción*).
2. En la parte superior de la pantalla, haz clic en la pestaña **Rules** (Reglas).
3. Verás un editor de texto con código. Borra todo su contenido y pega exactamente el siguiente código de seguridad profesional:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Reglas para el perfil de cada usuario
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Reglas para los códigos de acceso (HLG y PRO)
    match /accessCodes/{codeId} {
      allow read: if request.auth != null;
      allow update: if request.auth != null 
                    && request.resource.data.usedBy == request.auth.uid
                    && (resource.data.usedBy == null || resource.data.usedBy == request.auth.uid);
      allow create, delete: if false;
    }
  }
}
```

4. Haz clic en el botón azul **Publish** (Publicar) en la esquina superior derecha.
   * *Nota:* Estas reglas no bloquean tu desarrollo local. Podrás seguir probando en `localhost:5000` y emuladores sin problemas, siempre y cuando inicies sesión en la app con algún correo/Google.

---

## 3. Cómo Crear Códigos de Acceso de Único Uso

Tus códigos ya son de **único uso por diseño**. La lógica que programamos funciona así:
* El administrador (tú) crea el código en la base de datos y deja el campo `usedBy` vacío (`null`).
* Cuando un usuario introduce el código en la app, la app escribe su identificador de usuario (`uid`) en el campo `usedBy`.
* Gracias a las reglas de seguridad que acabamos de guardar, Firebase **rechazará cualquier intento de otra persona de cambiar un código que ya tenga un `usedBy` registrado**. Por lo tanto, nadie más podrá reutilizarlo.

### Paso a paso para crear un código en la consola:

1. Ve a **Firestore Database** en el menú izquierdo.
2. Asegúrate de estar en la pestaña **Data** (Datos) en la parte superior.
3. En la primera columna llamada *Collections* (Colecciones), busca la colección llamada **`accessCodes`** y haz clic sobre ella.
4. En la parte superior de la segunda columna (*Documents*), haz clic en **`+ Add document`** (Añadir documento).
5. Se abrirá una ventana emergente. Rellena los campos exactamente como sigue:
   * **Document ID (ID de documento):** Escribe aquí el código que le vas a dar al usuario. Utiliza mayúsculas, guiones y números para que se vea premium. E.g.: `NAVIMAP-HLG-PROMO-1234`
   * **Campos (Fields):**
     1. Campo 1:
        * *Field name:* **`active`**
        * *Type:* **`boolean`**
        * *Value:* **`true`**
     2. Campo 2:
        * Haz clic en *Add field*.
        * *Field name:* **`plan`**
        * *Type:* **`string`**
        * *Value:* **`hlg`** (si es para Hacienda La Gloria) o **`pro`** (si es para el Plan Pro regular).
     3. Campo 3 (Opcional - para códigos de único uso limpios):
        * No necesitas añadir el campo `usedBy`. Al no existir o estar vacío, la app sabe que está libre. O bien puedes crearlo como *Field name:* `usedBy`, *Type:* `string`, y dejar su valor vacío.
6. Haz clic en **Save** (Guardar).

¡Listo! El código ya está activo y se consumirá la primera vez que un usuario lo registre.

---

## 4. Habilitar Proveedores de Autenticación

Para asegurarte de que los usuarios puedan registrarse e iniciar sesión:

1. En el menú lateral izquierdo, haz clic en **Authentication**.
2. Ve a la pestaña **Sign-in method** (Método de inicio de sesión) en la parte superior.
3. Asegúrate de que estén activos:
   * **Email/Password (Correo electrónico/contraseña):** Si no está activo, haz clic en él, actívalo y guarda.
   * **Google:** Para habilitarlo, haz clic en él, selecciona el correo de soporte de tu proyecto y actívalo.

---

## 5. Pruebas Locales (`localhost:5000`) y Android

* **Localhost:** Puedes seguir ejecutando `npm run dev` / `flutter run -d chrome --web-port=5000` tranquilamente. La base de datos aceptará tus peticiones porque las reglas permiten acceso a cualquier usuario que se autentique con su correo.
* **Compilación de Android:** Si ejecutas en Android en modo desarrollo (debug), todo funcionará. Cuando decidas generar el paquete para subirlo a la tienda o compartir el archivo `.apk`, recuerda agregar el código SHA-1 de tu firma de compilación en los **Ajustes de Proyecto** de Firebase Console para que la autenticación con Google sea permitida en el teléfono.
