import os

def crear_lecturas_csv(db, n):
    cursor = db["sensor_readings"].find().sort("fecha_y_hora", -1).limit(n)
    lecturas = list(cursor)
    
    if len(lecturas) < n:
        return {"error": f"Faltan datos. Solo hay {len(lecturas)} lecturas en la BD. Se requieren {n}."}

    lecturas.reverse()

    os.makedirs("arm64_data", exist_ok=True)
    ruta_archivo = os.path.join("arm64_data", "lecturas.csv")

    with open(ruta_archivo, mode="w", encoding="utf-8") as file:
        file.write("ID,TEMP,HUM_AIRE,HUM_SUELO_1,HUM_SUELO_2,LUZ,GAS,RIEGO_1,RIEGO_2\n")
        
        for index, doc in enumerate(lecturas, start=1):
            val = doc.get("valor", {})
            
            temp = int(val.get("temp", 0))
            hum = int(val.get("hum", 0))
            suelo1 = int(val.get("suelo1", 0))
            suelo2 = int(val.get("suelo2", 0))
            luz = int(val.get("luz", 0))
            gas = int(val.get("gas", 0))
            
            riego1 = 0 
            riego2 = 0 

            linea = f"{index},{temp},{hum},{suelo1},{suelo2},{luz},{gas},{riego1},{riego2}\n"
            file.write(linea)
    
        file.write("$\n")

    return {"total": len(lecturas), "ruta": ruta_archivo}