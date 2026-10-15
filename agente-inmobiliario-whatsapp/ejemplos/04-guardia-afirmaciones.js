// EJEMPLO ILUSTRATIVO. Reescritura simplificada del patrón; no es el código del cliente.
//
// Corre DESPUÉS de que el agente redacta la respuesta y ANTES de enviarla.
// No confía en el texto del modelo: lo contrasta con el estado real de la base.
//
// Por qué existe: el agente llegó a confirmar una visita sin haber llamado a la
// herramienta de agendar, y a negar una visita que sí existía, aunque el prompt
// prohibía las dos cosas. El prompt orienta; no controla.

const BLOQUEAR = true; // en modo observación (false) detecta y registra, pero deja pasar

const AFIRMA_CITA = /\b(qued(o|ó|aste) agendad[oa]|tu visita (qued[oó]|est[aá]) (confirmada|agendada))\b/i;
const NIEGA_CITA  = /\bno tienes (ninguna )?visitas? agendadas?\b/i;

function revisar(texto, estado) {
  // estado viene de la base: { citasActivas, agendoEnEsteTurno, cancelacionEnEsteTurno }
  const hallazgos = [];

  if (AFIRMA_CITA.test(texto) && estado.citasActivas === 0 && !estado.agendoEnEsteTurno) {
    hallazgos.push('afirma_cita_inexistente');
  }
  // Más grave que la anterior: falla en silencio (el cliente no va y nadie se entera).
  if (NIEGA_CITA.test(texto) && estado.citasActivas > 0 && !estado.cancelacionEnEsteTurno) {
    hallazgos.push('niega_cita_existente');
  }

  const bloqueado = BLOQUEAR && hallazgos.length > 0;
  return {
    bloqueado,
    hallazgos,
    // Si se bloquea, el cliente recibe un texto neutro y la conversación pasa a un asesor.
    texto: bloqueado ? 'Déjame confirmarlo con un asesor y te escribo enseguida.' : texto,
  };
}

// Datos ficticios:
console.log(revisar('¡Listo! Quedaste agendado para el martes.',
  { citasActivas: 0, agendoEnEsteTurno: false, cancelacionEnEsteTurno: false }));
// -> bloqueado: true, hallazgos: ['afirma_cita_inexistente']
