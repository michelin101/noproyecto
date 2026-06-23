import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { API_URL } from '../config';

export default function Login() {
    const [usuario, setUsuario] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState(null);
    const [cargando, setCargando] = useState(false);
    const navigate = useNavigate();

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError(null);
        setCargando(true);

        try {
            const response = await fetch(`${API_URL}/api/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ usuario, password }),
            });

            const data = await response.json();

            if (!response.ok) {
                setError(data.error || "No se pudo iniciar sesion");
                return;
            }

            sessionStorage.setItem('autenticado', 'true');
            sessionStorage.setItem('usuario', data.usuario);
            navigate('/');
        } catch (err) {
            setError("Error de conexion con el backend. Verificar que esta corriendo");
        } finally {
            setCargando(false);
        }
    };

    return (
        <div style={styles.container}>
            <form onSubmit={handleSubmit} style={styles.card}>
                <h1 style={styles.titulo}>Invernadero Inteligente IoT</h1>
                <p style={styles.subtitulo}>Inicia sesión para continuar</p>

                <label style={styles.label}>Usuario</label>
                <input
                    type="text"
                    value={usuario}
                    onChange={(e) => setUsuario(e.target.value)}
                    style={styles.input}
                    autoFocus
                    required
                />

                <label style={styles.label}>Contraseña</label>
                <input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    style={styles.input}
                    required
                />

                {error && <div style={styles.error}>{error}</div>}

                <button type="submit" disabled={cargando} style={styles.boton}>
                    {cargando ? 'Verificando...' : 'Iniciar sesión'}
                </button>
            </form>
        </div>
    );
}

const styles = {
    container: {
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: '#0f172a',
        fontFamily: 'system-ui, -apple-system, sans-serif',
    },
    card: {
        background: '#ffffff',
        padding: '40px',
        borderRadius: '16px',
        width: '340px',
        boxShadow: '0 10px 25px rgba(0,0,0,0.3)',
        display: 'flex',
        flexDirection: 'column',
    },
    titulo: { margin: 0, fontSize: '20px', fontWeight: 800, color: '#0f172a', textAlign: 'center' },
    subtitulo: { margin: '6px 0 24px 0', fontSize: '13px', color: '#64748b', textAlign: 'center' },
    label: { fontSize: '12px', fontWeight: 600, color: '#334155', marginBottom: '6px' },
    input: { padding: '10px 12px', marginBottom: '16px', borderRadius: '8px', border: '1px solid #cbd5e1', fontSize: '14px' },
    error: { backgroundColor: '#fef2f2', color: '#b91c1c', border: '1px solid #fecaca', borderRadius: '8px', padding: '8px 12px', fontSize: '13px', marginBottom: '16px' },
    boton: { backgroundColor: '#1e3a8a', color: '#ffffff', border: 'none', borderRadius: '8px', padding: '12px', fontSize: '14px', fontWeight: 700, cursor: 'pointer' },
};