import { Navigate } from 'react-router-dom';

export default function RutaProtegida({ children }) {
    const autenticado = sessionStorage.getItem('autenticado') === 'true';

    if (!autenticado) {
        return <Navigate to="/login" replace />;
    }

    return children;
}