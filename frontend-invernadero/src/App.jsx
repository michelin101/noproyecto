import { BrowserRouter, Routes, Route, Link } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { connectMQTT } from './services/mqttService';

import Dashboard from './pages/Dashboard';
import Controles from './pages/Controles';
import Analisis from './pages/Analisis';

function App() {
  const [datosSensores, setDatosSensores] = useState({});

  useEffect(() => {
    connectMQTT((topic, payload) => {
      setDatosSensores(prev => ({ ...prev, [topic]: payload }));
    });
  }, []);

  const estadoGlobal = datosSensores['grupo19/invernadero/estado/global'] || 'ESPERANDO...';

  return (
    <BrowserRouter>
      <div className="app-container">
        <header className="navbar">
          <div>
            <h1>Invernadero Inteligente IoT</h1>
            <p>Centro de Control - Proyecto Grupo 19</p>
            <div className="nav-links">
              <Link to="/">Dashboard</Link>
              <Link to="/controles">Controles</Link>
              <Link to="/analisis">Análisis ARM64</Link>
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <p style={{ color: 'var(--text-muted)' }}>Estado Global</p>
            <div className="status-badge" style={{ color: estadoGlobal === 'EMERGENCIA' ? 'var(--color-red)' : 'var(--color-green)'}}>
              {estadoGlobal}
            </div>
          </div>
        </header>
        
        <main>
          <Routes>
            <Route path="/" element={<Dashboard datos={datosSensores} />} />
            <Route path="/controles" element={<Controles />} />
            <Route path="/analisis" element={<Analisis />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
}

export default App;