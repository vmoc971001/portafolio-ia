// EJEMPLO ILUSTRATIVO, datos ficticios. Versión reducida del nodo real de n8n.
// Problema: el mensaje de texto libre lo clasifica un LLM, que además escribe una
// frase amable. Si esa frase dice un precio o "listo, lo registré", la persona
// cree algo que el sistema nunca hizo.
// Solución: el LLM no ve ningún dato y no ejecuta nada. Su intención se veta
// contra una lista cerrada y su frase se descarta ENTERA (no se "limpia") si trae
// un dígito, un $, un enlace, un nombre del catálogo o un verbo de acción. Lo que
// la persona tiene que hacer lo escribe el sistema. Correr: node 03-...js

const INTENCIONES = ['saludo', 'pedir_ayuda', 'quiere_cargar', 'fuera_de_alcance', 'desconocida'];
const NOMBRES = ['marca a', 'marca b', 'cadena 1'];            // catálogo ficticio
const ACCIONES = /\b(registr|anul|correg|guard|borr|elimin|confirm)/;
const plano = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

function vetar(prosa) {
  if (typeof prosa !== 'string' || prosa.trim() === '') return 'vacia';
  if (/[0-9]/.test(prosa)) return 'digito';      // el modelo no vio precios: un número es inventado
  if (/\$/.test(prosa)) return 'signo_pesos';
  if (/https?:|www\.|@/i.test(prosa)) return 'enlace';
  if (NOMBRES.some((n) => plano(prosa).includes(n))) return 'nombre_propio';
  if (ACCIONES.test(plano(prosa))) return 'verbo_de_accion';
  return null;
}

function responder(salidaDelModelo) {
  const intencion = INTENCIONES.includes(salidaDelModelo.intencion) ? salidaDelModelo.intencion : 'desconocida';
  const veto = vetar(salidaDelModelo.prosa);
  const apertura = veto ? 'Hola.' : salidaDelModelo.prosa;    // vetada: texto fijo, el bot nunca queda mudo
  return { intencion, veto, texto: apertura + ' Mandame la foto del cartel.' };
}

const casos = [
  { intencion: 'saludo', prosa: '¡Hola! Qué bueno leerte.' },
  { intencion: 'quiere_cargar', prosa: 'Listo, ya quedó registrado.' },
  { intencion: 'saludo', prosa: 'La Marca A está a $9.900 hoy.' },
  { intencion: 'borrar_todo', prosa: 'Dale.' },
];
for (const c of casos) console.log(JSON.stringify(responder(c)));
// Esperado: veto null | verbo_de_accion | digito | null, con intención "desconocida" en el último.
