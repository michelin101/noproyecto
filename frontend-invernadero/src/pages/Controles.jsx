import { publishCommand } from '../services/mqttService';

export default function Controles() {

  const handleCommand = (topicSuffix, action) => {
    publishCommand(topicSuffix, action);
    alert(`Comando ${action} enviado a invernadero/${topicSuffix}`);
  };

  return (
    <div className="card" style={{ maxWidth: '600px', margin: '0 auto' }}>
      <h2 className="card-title">Panel de Control Remoto</h2>
      
      <button className="btn btn-blue" onClick={() => handleCommand('control/manual', 'TOGGLE_MODO')}>
        Cambiar Modo Automático/Manual
      </button>

     <div style={{ margin: '20px 0', borderTop: '1px dashed var(--border-color)', paddingTop: '20px' }}>
        <button className="btn btn-green" onClick={() => handleCommand('actuadores/riego/control', 'TOGGLE')}>
          Activar/Desactivar Riego Manual
        </button>
      </div>

      <div style={{ display: 'flex', gap: '10px', justifyContent: 'center' }}>
        <button className="btn btn-green" onClick={() => handleCommand('actuadores/luces/control', 'TOGGLE')}>
          Alternar Luces
        </button>
        
        <button className="btn btn-blue" onClick={() => handleCommand('actuadores/ventilador/control', 'TOGGLE')}>
          Alternar Ventilación
        </button>

        <button className="btn btn-red" onClick={() => handleCommand('actuadores/alarma/control', 'TOGGLE')}>
          Silenciar/Activar Alarma
        </button>
      </div>
    </div>
  );
}