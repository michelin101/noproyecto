import { useEffect, useState } from 'react';
import { API_URL } from '../config';

const BADGE = {
  EMERGENCIA: { bg: '#fee2e2', color: '#991b1b', border: '#fecaca' },
  ADVERTENCIA: { bg: '#fffbeb', color: '#92400e', border: '#fef3c7' },
  NORMAL: { bg: '#ecfdf5', color: '#065f46', border: '#a7f3d0' },
  RIEGO_ACTIVO: { bg: '#eff6ff', color: '#1e40af', border: '#bfdbfe' },
  default: { bg: '#f8fafc', color: '#475569', border: '#e2e8f0' },
};

function getBadge(texto = '') {
  const upper = String(texto).toUpperCase();
  for (const key of Object.keys(BADGE)) {
    if (upper.includes(key)) return BADGE[key];
  }
  return BADGE.default;
}

function Badge({ texto }) {
  const { bg, color, border } = getBadge(texto);
  return (
    <span style={{
      background: bg, color, border: `1px solid ${border}`,
      fontSize: '11px', fontWeight: 600,
      padding: '3px 10px', borderRadius: '99px',
      whiteSpace: 'nowrap', display: 'inline-flex', alignItems: 'center'
    }}>
      {texto}
    </span>
  );
}

const getNestedValue = (obj, path) => {
  return path.split('.').reduce((acc, part) => acc && acc[part], obj);
};

function Tabla({ titulo, filas, columnas, compactNumbers = false }) {
  return (
    <div style={styles.tableCard}>
      <div style={styles.tableHeader}>
        <h3 style={styles.tableTitle}>{titulo}</h3>
        <span style={styles.recordCount}>{filas.length} registros</span>
      </div>

      {filas.length === 0 ? (
        <div style={styles.emptyState}>
          <svg style={styles.emptyIcon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M20.25 14.15v4.25c0 1.06-.84 1.9-1.9 1.9H5.65c-1.06 0-1.9-.84-1.9-1.9v-4.25m16.5 0V9.85c0-1.06-.84-1.9-1.9-1.9H5.65c-1.06 0-1.9.84-1.9 1.9v4.3m16.5 0h-16.5M12 3v13.5m-3.75-3.75L12 16.5l3.75-3.75" />
          </svg>
          <p>Sin registros en las últimas horas.</p>
        </div>
      ) : (
        <div style={styles.scrollContainer}>
          <table style={styles.table}>
            <thead>
              <tr style={styles.theadTr}>
                {columnas.map(c => (
                  <th key={c.key} style={{ ...styles.th, textAlign: c.numeric ? 'right' : 'left' }}>
                    {c.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filas.map((fila, i) => (
                <tr key={i} style={{ ...styles.tbodyTr, backgroundColor: i % 2 === 0 ? '#ffffff' : '#f9fafb' }}>
                  {columnas.map(c => {
                    const valorCelda = getNestedValue(fila, c.key);

                    let valorFinal = valorCelda ?? '—';
                    if (typeof valorCelda === 'number' && compactNumbers) {
                      valorFinal = valorCelda % 1 === 0 ? valorCelda : valorCelda.toFixed(2);
                    }

                    return (
                      <td key={c.key} style={{
                        ...styles.td,
                        textAlign: c.numeric ? 'right' : 'left',
                        fontFamily: compactNumbers && c.numeric ? 'ui-monospace, monospace' : 'inherit',
                        fontWeight: compactNumbers && c.numeric ? 500 : 'inherit',
                      }}>
                        {c.badge ? <Badge texto={String(valorFinal)} /> : String(valorFinal)}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export default function Eventos() {
  const [eventos, setEventos] = useState([]);
  const [comandos, setComandos] = useState([]);
  const [lecturas, setLecturas] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState(null);

  const cargarDatos = async () => {
    try {
      const headers = { 'ngrok-skip-browser-warning': 'true' };
      const [resEv, resCm, resLc] = await Promise.all([
        fetch(`${API_URL}/api/historico/eventos`, { headers }),
        fetch(`${API_URL}/api/historico/comandos`, { headers }),
        fetch(`${API_URL}/api/historico/sensores`, { headers }),
      ]);

      if (!resEv.ok || !resCm.ok || !resLc.ok) throw new Error('Error de red');

      const [ev, cm, lc] = await Promise.all([resEv.json(), resCm.json(), resLc.json()]);
      setEventos(ev);
      setComandos(cm);
      setLecturas(lc);
      setError(null);
    } catch (err) {
      setError('Error de conexión con la Raspberry Pi. Verifica la IP.');
    } finally {
      setCargando(false);
    }
  };

  useEffect(() => {
    cargarDatos();
    const interval = setInterval(cargarDatos, 15000);
    return () => clearInterval(interval);
  }, []);

  if (cargando) return (
    <div style={styles.loadingContainer}>
      <div className="spinner"></div>
      <p style={{ marginTop: '10px' }}>Cargando historial...</p>
    </div>
  );

  if (error) return (
    <div style={styles.errorContainer}>
      <svg style={{ width: '24px', height: '24px' }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
      </svg>
      <span>{error}</span>
    </div>
  );

  return (
    <div style={styles.pageContainer}>
      <header style={styles.pageHeader}>
        <h1 style={styles.pageTitle}>Panel de Control - G19</h1>
        <p style={styles.pageSubtitulo}>Historial detallado del sistema de invernadero</p>
      </header>

      <Tabla
        titulo="Monitoreo Crítico de Sensores (Últimas 100)"
        filas={lecturas}
        compactNumbers={true}
        columnas={[
          { key: 'fecha_y_hora', label: 'Fecha / Hora' },
          { key: 'valor.temp', label: 'Temp (°C)', numeric: true },
          { key: 'valor.hum', label: 'Hum Aire (%)', numeric: true },
          { key: 'valor.suelo1', label: 'Suelo 1 (%)', numeric: true },
          { key: 'valor.suelo2', label: 'Suelo 2 (%)', numeric: true },
          { key: 'valor.luz', label: 'Luz (lux)', numeric: true },
          { key: 'valor.gas', label: 'Gas (ppm)', numeric: true },
          { key: 'estado_relacionado', label: 'Estado', badge: true },
        ]}
      />

      <div style={styles.gridDosColumnas}>
        <Tabla
          titulo="Bitácora de Eventos y Alertas"
          filas={eventos}
          columnas={[
            { key: 'fecha_y_hora', label: 'Fecha / Hora' },
            { key: 'tipo_de_dato', label: 'Tipo' },
            { key: 'valor', label: 'Evento', badge: true },
            { key: 'estado_relacionado', label: 'Nivel', badge: true },
          ]}
        />

        <Tabla
          titulo="Historial de Comandos MQTT"
          filas={comandos}
          columnas={[
            { key: 'fecha_y_hora', label: 'Fecha / Hora' },
            { key: 'valor', label: 'Comando', badge: true },
            { key: 'origen', label: 'Tópico Origen' },
          ]}
        />
      </div>
    </div>
  );
}

const styles = {
  pageContainer: {
    padding: '30px',
    backgroundColor: '#f1f5f9',
    minHeight: '100vh',
    fontFamily: 'system-ui, -apple-system, sans-serif'
  },
  pageHeader: {
    marginBottom: '30px',
    paddingBottom: '15px',
    borderBottom: '1px solid #e2e8f0'
  },
  pageTitle: {
    margin: 0,
    fontSize: '28px',
    fontWeight: 800,
    color: '#0f172a',
    letterSpacing: '-0.5px'
  },
  pageSubtitulo: {
    margin: '5px 0 0 0',
    color: '#64748b',
    fontSize: '16px'
  },
  gridDosColumnas: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(450px, 1fr))',
    gap: '24px'
  },
  tableCard: {
    background: '#ffffff',
    border: '1px solid #e2e8f0',
    borderRadius: '16px',
    boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03)',
    overflow: 'hidden',
    marginBottom: '24px',
    display: 'flex',
    flexDirection: 'column'
  },
  tableHeader: {
    padding: '18px 24px',
    borderBottom: '1px solid #f1f5f9',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#ffffff'
  },
  tableTitle: {
    margin: 0,
    fontSize: '17px',
    fontWeight: 700,
    color: '#1e3a8a'
  },
  recordCount: {
    fontSize: '12px',
    color: '#94a3b8',
    fontWeight: 500,
    backgroundColor: '#f8fafc',
    padding: '4px 10px',
    borderRadius: '99px'
  },
  scrollContainer: {
    overflowX: 'auto',
    flexGrow: 1
  },
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    fontSize: '13px',
    color: '#334155'
  },
  th: {
    padding: '12px 16px',
    color: '#64748b',
    fontWeight: 600,
    textTransform: 'uppercase',
    letterSpacing: '0.5px',
    fontSize: '11px',
    borderBottom: '2px solid #f1f5f9'
  },
  td: {
    padding: '10px 16px',
    verticalAlign: 'middle',
    borderBottom: '1px solid #f1f5f9'
  },
  tbodyTr: {
    transition: 'background-color 0.15s ease'
  },
  loadingContainer: {
    padding: '100px',
    textAlign: 'center',
    color: '#64748b',
    backgroundColor: '#f1f5f9',
    minHeight: '100vh'
  },
  errorContainer: {
    padding: '20px',
    margin: '30px',
    color: '#b91c1c',
    backgroundColor: '#fef2f2',
    border: '1px solid #fecaca',
    borderRadius: '12px',
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    fontWeight: 500
  },
  emptyState: {
    padding: '60px 24px',
    textAlign: 'center',
    color: '#94a3b8',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '15px'
  },
  emptyIcon: {
    width: '48px',
    height: '48px',
    color: '#cbd5e1'
  }
};