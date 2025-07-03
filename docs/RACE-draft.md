## Entidad: Carrera

El contrato inteligente de las carreras se encarga de manejar la agenda de carreras, inscribir caballos y premiarlos cuando ganan. Otra gran responsabilidad de este contrato es llevar a cabo la implementación de la carrera y determinar cuáles son los ganadores a partir de una serie de números aleatorios, que llamaremos "semillas", aportadas por los mismos usuarios que toman el papel de oráculos.


### Etapas de la Carrera



1. **Etapa 0 – Antes de empezar**: Se aceptan inscripciones y seeds de usuarios. Solo se almacenan los últimos 20 seeds recibidos.
2. **Etapa 1 – Carrera en curso**: El primer seed recibido tras la hora de inicio desencadena la carrera. Cada nuevo seed sirve para calcular los movimientos de los caballos, generando un avance iterativo controlado por índices de tiempo discretos. La lógica se asegura de registrar la historia de la carrera de forma progresiva y sin posibilidad de alteración del pasado.
3. **Etapa 2 – Finalizada**: Una vez se alcanza el máximo de seeds o el tiempo final, se cierra la carrera. Se limpian los datos intermedios y se emite un evento con los resultados.
