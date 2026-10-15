# Workflows de n8n

Un solo workflow de 32 nodos agrupa las cuatro etapas. Están en el mismo workflow porque todas parten del
mismo disparador de Telegram y de la misma puerta. Se enumeran P01 a P04 para distinguirlas. Aquí solo se
describen los nodos; el JSON exportado no se publica.

Conteo por tipo de nodo: 10 de código, 8 de envío por Telegram, 7 de PostgreSQL, 3 condicionales, 2
llamadas HTTP al modelo, 1 enrutador y 1 disparador.

## Conversación: puerta y sesión (P01)

| Nodo | Función |
|---|---|
| Disparador de Telegram | Recibe cada mensaje: texto, ubicación o foto. |
| Puerta | Busca al remitente en `usuarios`. Si no está activo, no se procesa nada (falla cerrado). |
| Estado | Lee la sesión vigente y la pregunta pendiente, solo si la sesión sigue viva. |
| Enrutador | Decide el camino según el tipo de mensaje y lo que el bot está esperando (sucursal, corte, marca, confirmación). |
| Sucursales cercanas | Calcula la distancia (haversine) y devuelve las más cercanas, con un tope de 1 km. |
| Armar lista / Responder lista | Arma la lista numerada y la envía. |
| Abrir sesión / ¿Se abrió? | Abre la sesión en la sucursal elegida; si el número no es válido, lo dice. |
| Confirmar sesión, Número inválido, Pedir ubicación, Responder | Mensajes fijos, con escape de HTML. |
| Armar respuesta | El texto para un mensaje libre cuando no interviene el recepcionista. |

## Lectura del cartel (P02)

| Nodo | Función |
|---|---|
| Prompt | Arma la instrucción para el modelo: rol de lector de carteles y diez reglas (separador de miles, precio vigente frente al tachado, cantidad obligatoria, no inventar la marca, texto crudo, traducir a los ejes sin inventar el dato, `null` si no es legible, cartel principal si hay varios, moneda, bajar la confianza sin culpa). |
| Bajar foto / A base64 | Descarga la imagen de Telegram y la convierte para enviarla. |
| Leer cartel | Llamada HTTP al modelo de visión (Responses API). |
| Extraer JSON | Separa el JSON de la respuesta sin romperse si viene mal formado. |
| Guardar captura | Escribe en `capturas` la foto, la respuesta cruda completa y lo leído, sin validar. |
| Armar lectura / Responder lectura | Le muestra a la persona lo que se leyó. |

## Registro: preguntar, confirmar, registrar (P03)

| Nodo | Función |
|---|---|
| Captura para P03 | Prepara la captura en curso. |
| P03 avanzar | Consulta que decide qué falta (corte, marca, precio) y qué opciones mostrar, según el catálogo cerrado, las marcas autorizadas de la cadena y la confianza de cada campo. |
| P03 aplicar | Aplica la respuesta en una sola transacción: confirma, corrige o descarta; registra la observación; graba el alias solo con evidencia completa. |
| P03 ruta / Armar P03 / Responder P03 | Elige el mensaje siguiente y lo envía. |

## Recepcionista de texto libre (P04): escrito y probado contra el archivo, sin desplegar

| Nodo | Función |
|---|---|
| ¿Es texto? | Solo el texto libre pasa al recepcionista. |
| P04 contexto | Arma la entrada del modelo: solo el texto de la persona y una etiqueta de estado (con o sin sesión abierta). Nunca el nombre, la sucursal, precios ni marcas. |
| P04 clasificar | Llamada HTTP al LLM: devuelve una de 8 intenciones cerradas y una frase corta. |
| P04 responder | Veta la intención y la frase (ver [ejemplos/03](../ejemplos/03-veto-de-la-respuesta-del-llm.js)). Si la llamada falla, devuelve el mismo texto que *Armar respuesta*. |

## Procesos programados (fuera de n8n)

| Proceso | Función |
|---|---|
| Respaldo diario | Un `pg_dump` de la base del proyecto por cron, con validación del archivo. Falta probar la restauración. |
