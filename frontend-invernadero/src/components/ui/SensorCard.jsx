export default function SensorCard({ titulo, valor, unidad, colorHex }) {
  return (
    <div className="sensor-item">
      <div className="sensor-label">{titulo}</div>
      <div className="sensor-value" style={{ color: colorHex }}>
        {valor !== undefined ? `${valor} ${unidad}` : '--'}
      </div>
    </div>
  );
}