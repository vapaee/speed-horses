# Sistema de Carreras y Apuestas sobre Blockchain Telos

Este documento describe el diseño de un sistema descentralizado de carreras de caballos y apuestas desarrollado sobre Telos EVM. El sistema se compone de varios contratos inteligentes que representan distintas entidades del juego: caballos, carreras, apuestas y una moneda interna llamada HAY. A través de estos contratos, los usuarios pueden criar y mejorar caballos, competir en carreras y realizar apuestas con tokens TLOS.

## Descripción General

La aplicación está pensada para dos tipos de usuarios:

* **Propietarios de caballos**: poseen caballos representados como NFTs, los mejoran y los inscriben en carreras para competir y ganar recompensas.
* **Apostadores**: usuarios que participan apostando tokens TLOS sobre el resultado de las carreras.

El sistema se estructura en torno a cuatro contratos inteligentes principales:

1. **Caballo (Horse)**
2. **Carrera (Race)**
3. **Apuestas (Betting)**
4. **Moneda HAY (Hay Token)**

Cada contrato cumple un rol específico y trabaja en coordinación con los demás para mantener la lógica del juego de forma descentralizada y transparente.

---

## Contrato de Caballo (Horse)

Los caballos son tokens no fungibles (NFTs) del tipo ERC-721. Cada uno tiene un conjunto de propiedades que afectan su rendimiento en las carreras. Estas propiedades pueden ser mejoradas mediante un sistema de puntos y staking.

### Propiedades de Rendimiento

Los caballos tienen atributos que determinan su comportamiento durante la simulación de una carrera:

* **Aceleración**
* **Resistencia**
* **Velocidad mínima**
* **Velocidad máxima**
* **Suerte** (chance de bonificación aleatoria)
* **Curva** (bonus en curvas)
* **Recta** (bonus en rectas)

### Sistema de Puntos

Los caballos ganan puntos no asignados cuando obtienen buenas posiciones en una carrera. Estos puntos pueden asignarse manualmente a las propiedades de rendimiento, previo pago con tokens HAY. La asignación entra en un estado de *staking temporal*, donde el caballo queda bloqueado por un tiempo determinado por su propiedad de espera.

Cada caballo también mantiene un conteo de:

* **Puntos no asignados**
* **Puntos asignados**
* **Nivel**: calculado como el logaritmo base 2 del total de puntos (asignados + no asignados), truncado hacia abajo.

La única manera válida de otorgar puntos no asignados a un caballo es a través del contrato de la carrera, que debe estar autorizado por el contrato del caballo.

---

## Contrato de Carrera (Race)

Las carreras son simulaciones deterministas controladas por este contrato inteligente. Cada carrera se define por un tiempo de inicio y una longitud en metros (que determina su duración). A medida que los usuarios inscriben sus caballos, también proporcionan *seeds* que se utilizarán como fuente de aleatoriedad pseudoaleatoria para determinar el desarrollo de la carrera.

### Etapas de la Carrera

1. **Etapa 0 – Antes de empezar**: Se aceptan inscripciones y seeds de usuarios. Solo se almacenan los últimos 20 seeds recibidos.
2. **Etapa 1 – Carrera en curso**: El primer seed recibido tras la hora de inicio desencadena la carrera. Cada nuevo seed sirve para calcular los movimientos de los caballos, generando un avance iterativo controlado por índices de tiempo discretos. La lógica se asegura de registrar la historia de la carrera de forma progresiva y sin posibilidad de alteración del pasado.
3. **Etapa 2 – Finalizada**: Una vez se alcanza el máximo de seeds o el tiempo final, se cierra la carrera. Se limpian los datos intermedios y se emite un evento con los resultados.

Los caballos ganadores reciben puntos según su posición. Posteriormente, los usuarios pueden retirar a sus caballos y cobrar premios.

---

## Contrato de Apuestas (Betting)

El sistema de apuestas permite a los usuarios apostar tokens TLOS sobre el resultado de una carrera. Las apuestas deben realizarse antes de que falten menos de cinco minutos para el inicio de la carrera. Existen tres tipos de apuestas:

### Tipos de Apuesta

* **Posición**: Acertar la posición exacta (ej. primer lugar).
* **Dupla**: Acertar dos caballos en las posiciones 1 y 2, en ese orden exacto.
* **Trío**: Acertar tres caballos en las posiciones 1, 2 y 3, en ese orden.

### Resolución de Apuestas

Una vez la carrera finaliza, el contrato de la carrera llama al contrato de apuestas para calcular los valores finales:

* **Total apostado**
* **Total ganadores**
* **Total perdedores**
* **Comisión del sistema (fees)**
* **Total premios** (perdedores - fees)
* **Peso total de las apuestas ganadoras**

El *peso* de cada apuesta ganadora se calcula como la cantidad apostada multiplicada por el inverso de su probabilidad. Por ejemplo, una apuesta a una posición con 1/5 de probabilidad y 10 TLOS apostados tiene un peso de 50.

Los premios se reparten proporcionalmente según el peso de cada apuesta. La comisión del sistema se envía a una dirección configurable por el owner del contrato. Si no se ha enviado previamente, se transfiere al momento en que un apostador retira su premio.

---

## Moneda HAY

HAY es una moneda interna del sistema utilizada para:

* Pagar la inscripción de caballos en las carreras.
* Asignar puntos a propiedades de rendimiento o espera.
* Estimular la participación económica dentro del ecosistema.

El contrato que gestiona HAY no se describe en profundidad aquí, pero su uso es central para la progresión y personalización de los caballos.

---

## Conclusión

Este sistema combina NFTs, gamificación, aleatoriedad controlada y economía cripto en una experiencia completa de carreras y apuestas. Cada parte del sistema está cuidadosamente diseñada para asegurar transparencia, incentivos correctos y control descentralizado. La interacción entre contratos mantiene la integridad de los resultados y permite a los usuarios interactuar con plena confianza en los mecanismos que determinan tanto el desempeño de sus caballos como la resolución de sus apuestas.

