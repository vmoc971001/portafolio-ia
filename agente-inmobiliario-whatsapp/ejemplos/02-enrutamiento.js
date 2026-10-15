// EJEMPLO ILUSTRATIVO. Reescritura simplificada del patrón; no es el código del cliente.
//
// El enrutador NO le pregunta al LLM quién es el cliente. Usa dos hechos de la base:
//   - contacto.tipo  (lead / inquilino / propietario), registrado por el equipo o el CRM
//   - contacto.modo  (descubrimiento / agendamiento), que cambia una herramienta
//
// El modo vence a los 30 min de inactividad. Sin vencimiento quedaba "pegajoso":
// el cliente seguía en el subagente agendador, que no tiene búsqueda de inmuebles,
// y el modelo rellenaba el hueco inventando inmuebles.

const TTL_MODO_MS = 30 * 60 * 1000;

function modoVigente(contacto, ahora = Date.now()) {
  if (contacto.modo !== 'agendamiento') return contacto.modo || 'descubrimiento';
  const desde = contacto.modo_desde ? Date.parse(contacto.modo_desde) : 0;
  return ahora - desde > TTL_MODO_MS ? 'descubrimiento' : 'agendamiento';
}

function elegirSubagente(contacto) {
  if (contacto.tipo === 'inquilino') return 'subagente_inquilinos';
  if (contacto.tipo === 'propietario') return 'subagente_propietarios';
  return modoVigente(contacto) === 'agendamiento'
    ? 'subagente_agendador'
    : 'subagente_interesados';
}

// En el sistema real el vencimiento es un UPDATE en la base, no un cálculo en memoria:
// el orquestador compara el modo antes y después del turno para detectar un traspaso
// entre subagentes, y un modo cambiado solo "en memoria" produciría un traspaso falso.

// Datos ficticios:
console.log(elegirSubagente({ tipo: 'lead', modo: 'agendamiento',
  modo_desde: new Date(Date.now() - 45 * 60 * 1000).toISOString() }));
// -> 'subagente_interesados' (el modo venció)
