import { useEffect, useState } from 'react';
import { Line } from 'react-chartjs-2';
import 'chart.js/auto';
import SensorCard from '../components/ui/SensorCard';
import { API_URL } from '../config';

export default function Dashboard({ datos }) {
  const [historial, setHistorial] = useState({
    labels: [], temperatura: [], humedad: [], suelo1: [], suelo2: [], luz: [], gas: []
  });

  const [motorArm64, setMotorArm64] = useState(null);

  useEffect(() => {
    const fetchHistorico = async () => {
      try {
        const response = await fetch(`${API_URL}/api/historico/sensores`);
        const data = await response.json();

        if (Array.isArray(data)) {
          const labels = data.map(doc => doc.fecha_y_hora.split(' ')[1]);
          const temperatura = data.map(doc => doc.valor.temp);
          const humedad = data.map(doc => doc.valor.hum);
          const suelo1 = data.map(doc => doc.valor.suelo1);
          const suelo2 = data.map(doc => doc.valor.suelo2);
          const luz = data.map(doc => doc.valor.luz);
          const gas = data.map(doc => doc.valor.gas);

          setHistorial({ labels, temperatura, humedad, suelo1, suelo2, luz, gas });
        }
      } catch (error) {
        console.error("Error al cargar histórico:", error);
      }
    };

    fetchHistorico();
    const interval = setInterval(fetchHistorico, 10000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const fetchMotorArm64 = async () => {
      try {
        const response = await fetch(`${API_URL}/api/historico/arm64`);
        const data = await response.json();
        setMotorArm64(data);
      } catch (error) {
        console.error("Error al obtener datos del motor ARM64: ", error);
      }
    };

    fetchMotorArm64();
    const intervalo = setInterval(fetchMotorArm64, 5000);
    return () => clearInterval(intervalo);
  }, []);

  const renderGrafica = (titulo, dataArray, color) => {
    const chartData = {
      labels: historial.labels,
      datasets: [{
        label: titulo,
        data: dataArray,
        borderColor: color,
        backgroundColor: `${color}33`,
        tension: 0.3,
        pointRadius: 1,
        fill: true
      }]
    };

    const options = {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false }, title: { display: true, text: titulo } },
      scales: { x: { ticks: { maxTicksLimit: 8 } } }
    };

    return (
      <div style={{ height: '220px', marginBottom: '20px', backgroundColor: '#fff', padding: '10px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
        <Line data={chartData} options={options} />
      </div>
    );
  };

  return (
    <div className="grid-dashboard" style={{ display: 'flex', gap: '20px', flexWrap: 'wrap' }}>

      <div className="card" style={{ flex: '1 1 300px' }}>
        <h2 className="card-title">Lecturas Actuales</h2>
        <div className="grid-sensores">
          <SensorCard titulo="Temperatura" valor={datos['grupo19/invernadero/sensores/temperatura']} unidad="°C" colorHex="#ef4444" />
          <SensorCard titulo="Humedad" valor={datos['grupo19/invernadero/sensores/humedad_ambiente']} unidad="%" colorHex="#3b82f6" />
          <SensorCard titulo="Suelo 1" valor={datos['grupo19/invernadero/sensores/humedad_suelo_area1']} unidad="%" colorHex="#10b981" />
          <SensorCard titulo="Suelo 2" valor={datos['grupo19/invernadero/sensores/humedad_suelo_area2']} unidad="%" colorHex="#10b981" />
          <SensorCard titulo="Luz" valor={datos['grupo19/invernadero/sensores/luz']} unidad="lx" colorHex="#eab308" />
          <SensorCard titulo="Gas / Humo" valor={datos['grupo19/invernadero/sensores/gas_ppm']} unidad="ppm" colorHex="#94a3b8" />
        </div>

        <h2 className="card-title" style={{ marginTop: '30px' }}>Estado de Actuadores</h2>
        <ul className="list-actuadores">
          <li><span>Riego:</span> <span>{datos['grupo19/invernadero/actuadores/riego'] || 'RIEGO_OFF'}</span></li>
          <li><span>Ventilación:</span> <span>{datos['grupo19/invernadero/actuadores/ventilador'] || 'OFF'}</span></li>
          <li><span>Luces:</span> <span>{datos['grupo19/invernadero/actuadores/luces'] || 'OFF'}</span></li>
          <li><span>Alarma:</span> <span>{datos['grupo19/invernadero/actuadores/alarma'] || 'OFF'}</span></li>
          <li><span>Estado Global:</span> <span style={{ fontWeight: 'bold', color: 'var(--color-blue)' }}>{datos['grupo19/invernadero/estado/global'] || 'NORMAL'}</span></li>
        </ul>
      </div>

      <div className="card" style={{ flex: '1 1 300px' }}>
        <h2 className="card-title">Motor ARM64 — Decisión en Vivo</h2>

        <p style={{ fontSize: '11px', color: 'var(--text-muted)' }}>
          {motorArm64?.timestamp ? new Date(motorArm64.timestamp).toLocaleString() : 'N/A'}
        </p>

        <h3 style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '16px' }}>Decisión</h3>
        <p>{motorArm64?.decision || 'N/A'}</p>

        <h3 style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '16px' }}>Resultado / Indicadores</h3>
        <pre style={{ fontSize: '12px', background: '#f8fafc', padding: '8px', borderRadius: '6px', overflowX: 'auto' }}>
          {motorArm64?.result ? JSON.stringify(motorArm64.result, null, 2) : 'N/A'}
        </pre>

        <h3 style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '16px' }}>Errores estructurados</h3>
        {motorArm64?.status === 'ERROR' ? (
          <p style={{ color: 'var(--color-red)' }}>
            STATUS=ERROR / DETAIL={motorArm64.error_detail || 'N/A'}
          </p>
        ) : (
          <p style={{ color: 'var(--color-green)' }}>N/A</p>
        )}
      </div>

      <div className="card" style={{ flex: '2 1 600px' }}>
        <h2 className="card-title">Gráficas Históricas</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: '15px' }}>
          {renderGrafica('Temperatura (°C)', historial.temperatura, '#ef4444')}
          {renderGrafica('Humedad Ambiental (%)', historial.humedad, '#3b82f6')}
          {renderGrafica('Humedad Suelo Área 1 (%)', historial.suelo1, '#10b981')}
          {renderGrafica('Humedad Suelo Área 2 (%)', historial.suelo2, '#059669')}
          {renderGrafica('Nivel de Luz (%)', historial.luz, '#eab308')}
          {renderGrafica('Peligro de Gas (ppm)', historial.gas, '#64748b')}
        </div>
      </div>
    </div>
  );
}