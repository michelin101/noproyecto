import { BrowserRouter, Routes, Route, Link, useNavigate, useLocation } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { connectMQTT } from './services/mqttService';
import RutaProtegida from './components/RutaProtegida';

import Dashboard from './pages/Dashboard';
import Controles from './pages/Controles';
import Analisis from './pages/Analisis';
import Eventos from './pages/Eventos';
import Login from './pages/Login';


function Layout({ datosSensores }) {
  const navigate = useNavigate();
  const usuario = sessionStorage.getItem('usuario');

  const estadoGlobal = datosSensores['grupo19/invernadero/estado/global'] || 'ESPERANDO...';

  const cerrarSesion = () => {
    sessionStorage.removeItem('autenticado');
    sessionStorage.removeItem('usuario');
    navigate('/login');
  };

  return (
    <div className="app-container">
      <header className="navbar">
        <div>
          <h1>Invernadero Inteligente IoT</h1>
          <p>Centro de Control - Proyecto Grupo 19</p>
          <div className="nav-links">
            <Link to="/">Dashboard</Link>
            <Link to="/controles">Controles</Link>
            <Link to="/analisis">Análisis ARM64</Link>
            <Link to="/eventos">Eventos</Link>
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <p style={{ color: 'var(--text-muted)' }}>Estado Global</p>
          <div className="status-badge" style={{ color: estadoGlobal === 'EMERGENCIA' ? 'var(--color-red)' : 'var(--color-green)' }}>
            {estadoGlobal}
          </div>
          {usuario && (
            <div style={{ marginTop: '8px', display: 'flex', alignItems: 'center', gap: '10px', justifyContent: 'flex-end' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>{usuario}</span>
              <button onClick={cerrarSesion} className="btn btn-red" style={{ padding: '4px 10px', fontSize: '12px' }}>
                Cerrar sesión
              </button>
            </div>
          )}
        </div>
      </header>

      <main>
        <Routes>
          <Route path="/" element={<RutaProtegida><Dashboard datos={datosSensores} /></RutaProtegida>} />
          <Route path="/controles" element={<Controles />} />
          <Route path="/analisis" element={<Analisis />} />
          <Route path="/eventos" element={<Eventos />} />
        </Routes>
      </main>
    </div>
  );
}

function AppRoutes({ datosSensores }) {
  const location = useLocation();
  const enLogin = location.pathname === "/login";

  if (enLogin) {
    return (
      <Routes>
        <Route path='/login' element={<Login />} />
      </Routes>
    );
  }
  return <Layout datosSensores={datosSensores} />;
}

function App() {
  const [datosSensores, setDatosSensores] = useState({});

  useEffect(() => {
    connectMQTT((topic, payload) => {
      setDatosSensores(prev => ({ ...prev, [topic]: payload }));
    });
  }, []);

  return (
    <BrowserRouter>
      <AppRoutes datosSensores={datosSensores} />
    </BrowserRouter>
  );
}

export default App;