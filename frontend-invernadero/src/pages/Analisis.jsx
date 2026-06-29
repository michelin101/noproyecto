import React, { useState } from 'react';


const VARIABLES_COLUMNAS = {
    "Temperatura": "2",
    "Humedad Aire": "3",
    "Humedad Suelo 1": "4",
    "Humedad Suelo 2": "5",
    "Luminosidad": "6",
    "Calidad Aire (Gas)": "7",

};

const Analisis = () => {
    const [variableSeleccionada, setVariableSeleccionada] = useState("");
    const [resultados, setResultados] = useState(null);
    const [cargando, setCargando] = useState(false);
    const [errorGeneral, setErrorGeneral] = useState(null);

    const ejecutarAnalisis = async () => {
        if (!variableSeleccionada) {
            setErrorGeneral("Por favor, selecciona una variable a analizar.");
            return;
        }

        setCargando(true);
        setErrorGeneral(null);
        setResultados(null);

        const numeroColumna = VARIABLES_COLUMNAS[variableSeleccionada];

        try {
            const response = await fetch('http://192.168.0.14:5000/api/analizar', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ columna: numeroColumna }),
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || "Ocurrió un error al procesar la solicitud.");
            }

            setResultados(data.payload);

        } catch (error) {
            setErrorGeneral(error.message);
        } finally {
            setCargando(false);
        }
    };

    const renderizarMetricas = (metricas) => {
        if (!metricas || Object.keys(metricas).length === 0) {
            return <p style={styles.textoVacio}>Métricas no generadas o archivo vacío.</p>;
        }

        return (
            <div style={styles.metricasContainer}>
                {Object.entries(metricas).map(([clave, valor], index) => (
                    <div key={clave} style={{...styles.metricaRow, backgroundColor: index % 2 === 0 ? '#ffffff' : 'transparent'}}>
                        <span style={styles.metricaClave}>{clave}:</span>
                        <span style={styles.metricaValor}>{valor}</span>
                    </div>
                ))}
            </div>
        );
    };

    const renderizarModulo = (nombreModulo, datosModulo) => {
        if (!datosModulo) return null;

        const esExitoso = datosModulo.estado_ejecucion === "exitoso";

        return (
            <div key={nombreModulo} style={styles.moduloCard}>
                <div style={styles.moduloHeader}>
                    <h3 style={styles.moduloTitulo}>{nombreModulo}</h3>
                    {esExitoso ? (
                        <span style={styles.badgeExitoso}>✓ Exitoso</span>
                    ) : (
                        <span style={styles.badgeFallido}>✕ Fallido</span>
                    )}
                </div>
                
                {esExitoso ? (
                    <div style={styles.moduloContenido}>
                        {renderizarMetricas(datosModulo.metricas)}
                    </div>
                ) : (
                    <div style={styles.moduloContenidoCentro}>
                        <div style={styles.errorBox}>
                            <p style={styles.errorBoxTitulo}>Error en ejecución:</p>
                            <p style={styles.errorBoxTexto}>{datosModulo.error_detalle || "Falló sin detalles."}</p>
                        </div>
                        {datosModulo.stderr_raw && (
                            <div style={styles.stderrContainer}>
                                <p style={styles.stderrTitulo}>Salida de error (stderr):</p>
                                <pre style={styles.stderrPre}>{datosModulo.stderr_raw}</pre>
                            </div>
                        )}
                    </div>
                )}
            </div>
        );
    };

    return (
        <div style={styles.mainContainer}>
            <header style={styles.header}>
                <h1 style={styles.tituloPrincipal}>Análisis Estadístico</h1>
                <p style={styles.subtitulo}>Procesamiento ARM64</p>
            </header>
            
            <section style={styles.cardControles}>
                <h2 style={styles.seccionTitulo}>Controles de Análisis</h2>
                <div style={styles.gridControles}>
                    <div style={styles.inputGroup}>
                        <label htmlFor="variableSelect" style={styles.label}>Seleccionar Variable a Procesar</label>
                        <select 
                            id="variableSelect"
                            value={variableSeleccionada}
                            onChange={(e) => setVariableSeleccionada(e.target.value)}
                            style={styles.select}
                        >
                            <option value="">-- Selecciona una variable --</option>
                            {Object.keys(VARIABLES_COLUMNAS).map(nombre => (
                                <option key={nombre} value={nombre}>{nombre}</option>
                            ))}
                        </select>
                    </div>

                    <button 
                        onClick={ejecutarAnalisis} 
                        disabled={cargando}
                        style={{...styles.boton, opacity: cargando ? 0.7 : 1, cursor: cargando ? 'not-allowed' : 'pointer'}}
                    >
                        {cargando ? "Procesando..." : "Ejecutar Rutinas ARM64"}
                    </button>
                </div>
            </section>

            {errorGeneral && (
                <div style={styles.alertaError}>
                    <p style={styles.alertaErrorTitulo}>Error General</p>
                    <p style={styles.alertaErrorTexto}>{errorGeneral}</p>
                </div>
            )}

            {resultados && (
                <div style={styles.resultadosWrapper}>
                    <div style={styles.cardResumen}>
                        <h2 style={styles.seccionTitulo}>Resumen del Análisis</h2>
                        <div style={styles.gridResumen}>
                            <p><span style={styles.resumenLabel}>Variable:</span> {variableSeleccionada} (Columna {resultados.columna_analizada})</p>
                            <p><span style={styles.resumenLabel}>Registros:</span> {resultados.total_registros}</p>
                            <p><span style={styles.resumenLabel}>Fecha:</span> {resultados.fecha_y_hora}</p>
                            <p><span style={styles.resumenLabel}>Origen:</span> {resultados.origen}</p>
                        </div>
                    </div>

                    <div style={styles.gridModulos}>
                        {Object.entries(resultados.resultados).map(([nombreModulo, datosModulo]) => 
                            renderizarModulo(nombreModulo, datosModulo)
                        )}
                    </div>
                </div>
            )}
        </div>
    );
};


const styles = {
    mainContainer: {
        padding: '30px',
        backgroundColor: '#f9fafb',
        minHeight: '100vh',
        fontFamily: 'system-ui, -apple-system, sans-serif',
        color: '#111827'
    },
    header: {
        marginBottom: '40px'
    },
    tituloPrincipal: {
        fontSize: '2.25rem',
        fontWeight: '800',
        color: '#1e3a8a',
        margin: '0 0 5px 0',
        letterSpacing: '-0.02em'
    },
    subtitulo: {
        fontSize: '1.125rem',
        color: '#4b5563',
        margin: '0'
    },
    cardControles: {
        backgroundColor: '#ffffff',
        padding: '30px',
        borderRadius: '16px',
        border: '1px solid #f3f4f6',
        boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
        marginBottom: '40px'
    },
    seccionTitulo: {
        fontSize: '1.25rem',
        fontWeight: '700',
        color: '#1f2937',
        margin: '0 0 20px 0'
    },
    gridControles: {
        display: 'grid',
        gridTemplateColumns: '3fr 1fr',
        gap: '20px',
        alignItems: 'end'
    },
    inputGroup: {
        display: 'flex',
        flexDirection: 'column'
    },
    label: {
        fontSize: '0.875rem',
        fontWeight: '600',
        color: '#374151',
        marginBottom: '8px'
    },
    select: {
        padding: '14px',
        border: '1px solid #e5e7eb',
        borderRadius: '10px',
        backgroundColor: '#f9fafb',
        color: '#111827',
        fontSize: '1rem',
        outline: 'none'
    },
    boton: {
        padding: '14px',
        backgroundColor: '#2563eb',
        color: '#ffffff',
        border: 'none',
        borderRadius: '10px',
        fontWeight: '700',
        fontSize: '1rem',
        boxShadow: '0 4px 6px -1px rgba(37, 99, 235, 0.2)',
        transition: 'all 0.2s'
    },
    alertaError: {
        backgroundColor: '#fef2f2',
        borderLeft: '4px solid #ef4444',
        padding: '20px',
        borderRadius: '0 10px 10px 0',
        marginBottom: '40px',
        boxShadow: '0 1px 2px rgba(0,0,0,0.05)'
    },
    alertaErrorTitulo: {
        fontWeight: '700',
        color: '#7f1d1d',
        margin: '0 0 5px 0'
    },
    alertaErrorTexto: {
        color: '#991b1b',
        margin: '0',
        fontSize: '0.875rem'
    },
    resultadosWrapper: {
        display: 'flex',
        flexDirection: 'column',
        gap: '30px'
    },
    cardResumen: {
        backgroundColor: '#ffffff',
        padding: '25px',
        borderRadius: '16px',
        border: '1px solid #f3f4f6',
        boxShadow: '0 1px 3px rgba(0,0,0,0.05)'
    },
    gridResumen: {
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
        gap: '15px',
        backgroundColor: '#f9fafb',
        padding: '15px',
        borderRadius: '10px',
        border: '1px solid #f3f4f6',
        fontSize: '0.875rem'
    },
    resumenLabel: {
        fontWeight: '600',
        color: '#374151'
    },
    gridModulos: {
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(350px, 1fr))',
        gap: '25px'
    },
    moduloCard: {
        backgroundColor: '#ffffff',
        padding: '25px',
        borderRadius: '16px',
        border: '1px solid #e5e7eb',
        boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
        display: 'flex',
        flexDirection: 'column'
    },
    moduloHeader: {
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        borderBottom: '1px solid #f3f4f6',
        paddingBottom: '15px',
        marginBottom: '15px'
    },
    moduloTitulo: {
        fontSize: '1.1rem',
        fontWeight: '700',
        color: '#1f2937',
        margin: '0',
        textTransform: 'uppercase',
        letterSpacing: '0.05em'
    },
    badgeExitoso: {
        backgroundColor: '#dcfce3',
        color: '#166534',
        padding: '4px 12px',
        borderRadius: '9999px',
        fontSize: '0.75rem',
        fontWeight: '600'
    },
    badgeFallido: {
        backgroundColor: '#fee2e2',
        color: '#991b1b',
        padding: '4px 12px',
        borderRadius: '9999px',
        fontSize: '0.75rem',
        fontWeight: '600'
    },
    moduloContenido: {
        flexGrow: 1
    },
    moduloContenidoCentro: {
        flexGrow: 1,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center'
    },
    metricasContainer: {
        backgroundColor: '#f9fafb',
        border: '1px solid #f3f4f6',
        borderRadius: '8px',
        padding: '8px',
        display: 'flex',
        flexDirection: 'column',
        gap: '4px'
    },
    metricaRow: {
        display: 'flex',
        justifyContent: 'space-between',
        padding: '6px 8px',
        borderRadius: '4px',
        fontSize: '0.875rem',
        fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace'
    },
    metricaClave: {
        fontWeight: '600',
        color: '#374151'
    },
    metricaValor: {
        color: '#111827'
    },
    textoVacio: {
        fontSize: '0.875rem',
        color: '#6b7280',
        fontFamily: 'ui-monospace, monospace'
    },
    errorBox: {
        backgroundColor: '#fffbeb',
        borderLeft: '4px solid #fbbf24',
        padding: '15px',
        borderRadius: '0 8px 8px 0',
        marginBottom: '15px'
    },
    errorBoxTitulo: {
        fontWeight: '600',
        color: '#78350f',
        margin: '0 0 4px 0',
        fontSize: '0.9rem'
    },
    errorBoxTexto: {
        color: '#92400e',
        margin: '0',
        fontSize: '0.85rem'
    },
    stderrContainer: {
        marginTop: '10px'
    },
    stderrTitulo: {
        fontSize: '0.75rem',
        fontWeight: '600',
        color: '#4b5563',
        marginBottom: '4px'
    },
    stderrPre: {
        backgroundColor: '#111827',
        color: '#f3f4f6',
        padding: '12px',
        borderRadius: '8px',
        fontSize: '0.75rem',
        overflowX: 'auto',
        fontFamily: 'ui-monospace, SFMono-Regular, Consolas, monospace',
        margin: '0'
    }
};

export default Analisis;