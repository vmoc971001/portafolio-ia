// EJEMPLO ILUSTRATIVO. Reescritura simplificada del patrón; no es el código del cliente.
//
// Problema: la memoria del chat guarda los mensajes, no los resultados de las herramientas.
// En el turno siguiente el modelo ya no tiene los IDs que vio, y si se los pedimos
// los inventa o los mezcla.
//
// Solución: cuando una herramienta lista opciones, el servidor guarda un mapa
// posición -> id en la fila del contacto. El modelo solo pasa la posición:
//   - inmuebles: letras  (A, B, C)
//   - horarios:  números (1, 2, 3)
// Dos alfabetos distintos para que "la 2" no pueda referirse a dos listas a la vez.

const FRESCURA_MAX_MS = 60 * 60 * 1000;

function resolverHorario(contacto, eleccion, ahora = Date.now()) {
  const n = Number.parseInt(String(eleccion).trim(), 10);
  const mapa = Array.isArray(contacto.ultimos_horarios) ? contacto.ultimos_horarios : [];
  const edad = ahora - Date.parse(contacto.horarios_en || 0);

  // Falla CERRADO: ante cualquier duda no se resuelve nada y se vuelve a listar.
  if (!Number.isInteger(n) || n < 1 || n > mapa.length) return { ok: false, motivo: 'fuera_de_rango' };
  if (!(edad <= FRESCURA_MAX_MS)) return { ok: false, motivo: 'mapa_vencido' };

  return { ok: true, horario_id: mapa[n - 1] };
}

function letraAIndice(letra) {
  const c = String(letra).trim().toUpperCase();
  return /^[A-Z]$/.test(c) ? c.charCodeAt(0) - 64 : 0; // 0 = inválido
}

// Datos ficticios:
const contacto = {
  ultimos_horarios: ['h-ficticio-01', 'h-ficticio-02'],
  horarios_en: new Date().toISOString(),
};
console.log(resolverHorario(contacto, '2'));  // { ok: true, horario_id: 'h-ficticio-02' }
console.log(resolverHorario(contacto, '7'));  // { ok: false, motivo: 'fuera_de_rango' }
console.log(letraAIndice('b'));               // 2
