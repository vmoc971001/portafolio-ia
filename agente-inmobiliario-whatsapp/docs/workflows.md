# Workflows de n8n

Solo la descripción de los nodos y su función: los JSON exportados pertenecen al cliente. Los nombres de nodo están simplificados. La numeración (W01, W05…) es la del proyecto.

**Patrones comunes**
- Cada herramienta del agente es un **sub-workflow** que empieza con un nodo `Normalizar inputs` (tipos, defaults, rechazo de entradas basura).
- Las operaciones no críticas (registrar eventos, notas) continúan aunque fallen, para no tumbar la respuesta al cliente.
- Toda herramienta registra un evento `tool_invocada`: así se puede auditar qué llamó realmente el agente en cada turno.

---

## 1. Conversación con clientes (WhatsApp)

### W01 · Orquestador principal
Recibe cada mensaje de Chatwoot y decide qué pasa con él.

| Etapa | Nodos | Función |
|---|---|---|
| Entrada | Webhook → Switch → Filtro mensaje | Solo procesa mensajes nuevos entrantes. |
| Multimedia | ¿Es audio? → Descargar → Transcribir (Whisper) | Convierte audios a texto. Las fotos y videos se asocian como evidencia de un reporte de daño abierto. |
| Botones | ¿Es respuesta de botón? → handler (W24) | Los toques en botones de plantilla van directo a su handler, sin pasar por el LLM. |
| Pausa | GET etiquetas → ¿Bot pausado? | Si el equipo tomó la conversación, el bot no responde. |
| Contacto | Buscar / Crear contacto | Un contacto nuevo nace como `lead`. |
| Debounce | Redis GET/SET → Esperar 8 s → ¿Soy líder? | Junta los mensajes que el cliente manda en ráfaga y deja que solo una ejecución responda. |
| Portal | Detectar link portal → Resolver inmueble por link → Contexto portal | Si el cliente pega el link de un anuncio, se identifica el inmueble antes de llamar al agente. |
| Enrutamiento | Leer modo (con vencimiento) → Preparar llamada → Invocar agente | Elige el subagente por tipo de contacto y modo de conversación. Si el agente cambió de modo, se hace un segundo salto al subagente correcto. |
| Guardias | Citas activas · Búsquedas recientes · Horarios ofrecidos · Acciones del turno → Guardia agendamiento → Resolución final | Contrastan lo que afirma el agente con la base: citas, horarios e inmuebles. Bloquean o sustituyen el texto y escalan a un asesor. |
| Salida | Dividir respuesta → Enviar a Chatwoot (con pausa entre mensajes) → Registrar evento | Envía la respuesta en mensajes cortos. |

### Subagentes (AI Agent + memoria en PostgreSQL + herramientas)
| Workflow | Atiende a | Herramientas |
|---|---|---|
| W05 · Interesados | Leads en búsqueda | buscar_propiedades, base de conocimiento, actualizar_contacto, iniciar_agendamiento, vincular_inmueble, marcar_interes, avisar_asesor |
| W05b · Agendador | Leads eligiendo horario | consultar_disponibilidad, agendar_visita, consultar_mis_citas, cancelar_visita, volver_a_busqueda, avisar_asesor |
| W06 · Inquilinos | Arrendatarios | consultar_pagos, preparar_reporte, confirmar_tipo_dano, marcar_intento_sin_evidencia, base de conocimiento |
| W07 · Propietarios | Dueños de inmuebles | consultar_pagos, base de conocimiento |
| W08 · Mantenimientos | Reportes de daño | **En desarrollo.** Mismas herramientas de reporte que W06, que es quien atiende hoy esos reportes. |

Los prompts de sistema definen el rol (agente virtual de la inmobiliaria, nunca "bot" ni "IA"), las reglas de cada flujo y cuándo escalar a un humano.

### Herramientas
| Workflow | Función |
|---|---|
| W09 · Buscar propiedades | Vectoriza la búsqueda, consulta pgvector filtrando por barrio, guarda el mapa de letras del resultado. Si no hay nada, sugiere barrios cercanos (≤ 3 km) por coordenadas. |
| W10 · Consultar disponibilidad | Traduce la letra del inmueble, consulta la agenda del CRM, guarda el mapa de números de horario. |
| W11 · Agendar visita | Envía el lead al CRM si hace falta, verifica que el horario siga libre, crea la cita en el CRM y en la base local, y construye la confirmación. Si falla, escala. |
| W21 · Consultar mis citas | Lista las visitas del contacto y guarda su mapa. |
| W22 · Cancelar visita | Valida el mapa, borra la cita en el CRM, actualiza la base y limpia el mapa vencido. |
| W23 · Cambiar modo | Cambia entre búsqueda y agendamiento. |
| W13 · Actualizar contacto | Guarda preferencias del lead y regenera su embedding. |
| W14a / W14d / W14e / W14 · Reporte de daño | Borrador → confirmar tipo → pedir evidencia (máx. 2 intentos) → registrar y avisar al equipo de servicio. |
| W15 · Consultar pagos | Pagos del inquilino o del propietario. |
| W19 · Avisar asesor | Nota privada en Chatwoot, asignación al equipo, etiqueta de pausa y aviso a Telegram. |
| W41 · Vincular inmueble | Registra la oferta de un propietario y la deriva a un asesor. |
| W12 · Base de conocimiento | RAG sobre preguntas frecuentes y políticas. |

## 2. Procesos programados
| Workflow | Frecuencia | Función |
|---|---|---|
| Espejo de inventario | Diario | Descarga el Excel del CRM, hace UPSERT de inmuebles y portales, genera embeddings y marca los no disponibles. |
| W27 · Sync horario | Cada hora | Completa campos de inmuebles y llena el espejo local de clientes del CRM. |
| W28 / W29 · Envío de leads | 5 veces al día | Deduplica por teléfono contra el espejo local; enlaza o crea en el CRM. |
| W02 · Recordatorios | Diario | Plantillas de WhatsApp con botones Confirmar/Cancelar, 24 h antes y el día de la visita. Solo marca "enviado" si la API lo confirmó. |
| W24 · Botones | Al tocar | Resuelve la cita por teléfono en el servidor y aplica la acción. |
| W04 · Watcher | Cada 2 min | Lee eventos de NocoDB y avisa al cliente (seguimiento post-visita, resultado de estudio, avance de mantenimiento). |
| W20 · Cierre de agenda | Diario | Vence horarios pasados y pasa citas a "por cerrar". |
| W25 · Mora | Semanal | Marca pagos vencidos y avisa al equipo. |
| W30 · Canario del CRM | Cada 30 min | Detecta CRM caído o espejo atrasado; avisa una vez, con un mensaje distinto por causa y enfriamiento para no saturar. |
| W50 · Historial de barrios | Diario | Agrega barrios nuevos con su punto aproximado; nunca borra. |
| W16 / W17 / W18 | Manual | Generación de embeddings (base de conocimiento, inmuebles, mantenimientos). |

## 3. Agente interno del equipo (Telegram)
| Workflow | Función |
|---|---|
| W31 · Orquestador | Autoriza al usuario contra la base (el modelo nunca elige la identidad), enruta y maneja la confirmación por código. |
| W32 · Subagente | Agente con herramientas de consulta y de "preparar acción". |
| W35 / W36 / W37 / W39 | Agenda del día, ficha de contacto, conversaciones pausadas, horarios de un inmueble. |
| W40 / W42 | Preparan una acción (reactivar bot, cancelar o reprogramar visita) y muestran una vista previa. **No ejecutan nada.** |
| W33 | Registra la acción pendiente. |
| W34 · Ejecutor | Ejecuta solo lo confirmado. Para reprogramar: agenda la nueva → si funcionó, cancela la vieja → avisa al cliente. |
| W43 · Aviso al cliente | Plantilla de WhatsApp; el envío se da por hecho solo si la API devuelve un id. |

## 4. Escritos, sin desplegar
| Workflow | Función |
|---|---|
| W45 · Centinela de errores | Error Trigger → aviso a Telegram ante el fallo de cualquier workflow. |
| W47 / W48 / W48b / W49 / W49b · Difusiones | Marcar interés, etiquetar contactos en Chatwoot y enviar campañas programadas desde NocoDB. |
