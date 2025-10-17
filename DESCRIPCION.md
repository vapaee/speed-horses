# Sistema de Carreras y Apuestas sobre Blockchain Telos

Este documento describe el diseño de un sistema descentralizado de carreras de caballos y apuestas desarrollado sobre Telos EVM. El sistema se compone de varios contratos inteligentes que representan distintas entidades del juego: caballos, carreras, apuestas, herraduras y una moneda interna llamada HAY. A través de estos contratos, los usuarios pueden criar y mejorar caballos, competir en carreras y realizar apuestas con tokens TLOS.

## Descripción General

La aplicación está pensada para dos tipos de usuarios:

* **Propietarios de caballos**: poseen caballos con herraduras y vestimenta, representados todos como NFTs, los mejoran y los inscriben en carreras para competir y ganar recompensas.
* **Apostadores**: usuarios que participan apostando tokens TLOS sobre el resultado de las carreras. TLOS es la moneda principal de la blockchain.


Estos son los contratos que componen el sistema:

// TODO: Aquí hay que hacer un listado excausito de todos los contratos bajo la carpeta de contracts y explicar brevemente cual es su rol 

Cada contrato cumple un rol específico y trabaja en coordinación con los demás para mantener la lógica del juego de forma descentralizada y transparente.

---

## Caballo

Los caballos son tokens no fungibles (NFTs) del tipo ERC-721. Cada uno tiene un conjunto de propiedades que afectan su rendimiento en las carreras. Estas propiedades pueden ser mejoradas mediante un sistema de puntos y staking, más la combinación con herraduras..

### Propiedades de Rendimiento

Los caballos tienen atributos que determinan su comportamiento durante la simulación de una carrera:

* **Poder**: potencia todas las propiedades al la vez
* **Aceleración**: llega más rápido a su velocidad máxima.
* **Resistencia**: al fatigarse baja el rendimimento más lento.
* **Velocidad máxima**: velocidad máxima que puede dar el caballo (trunca el resultado final).
* **Velocidad mínima**: garantíza un mínimo avance.
* **Suerte**: chance de bonificación aleatoria
* **Curva**: bonus en curvas
* **Recta**: bonus en rectas

### Sistema de Puntos

Los caballos ganan puntos no asignados cuando obtienen buenas posiciones en una carrera. También pueden usar token HAY para comprar puntos al caballo. En ambos casos los puntos quedan acreditados al caballo pero permanecen sin asignar. Estos puntos pueden asignarse manualmente a las propiedades de rendimiento, previo pago con tokens HAY por punto asignado. La asignación entra en un estado de *staking temporal*, donde el caballo queda bloqueado (alimentándose) por un tiempo determinado por su propiedad de espera.

Cada caballo también mantiene un conteo de:

* **Puntos no asignados**: puntos obtenidos que no han sido asignados todavía
* **Puntos asignados**: puntos que fueron asignados a alguna propiedad de performance
* **Nivel**: calculado como el logaritmo base 2 del total de puntos (asignados + no asignados), truncado hacia abajo.

## Herraduras

Cada caballo debe vestir exactamente 4 herraduras para poder correr. Estas están implementadas con tokens no fungibles (NFTs) del tipo ERC-721 y cuentan con una cantidad de puntos asignados a algunas prepiedades de performance que se suman a las del caballo pera genera un total.

Las herraduras además tienen una duración que las va degradando con el tiempo hasta quedar inútiles. Para contrarestar este deterioro el usuario tien dos acciones que puede realizar:
* **Iron Redemption**: intenta reparar una herradura. El usuario puede pagar con HAY reintentos para tratar de mantener la mayor pureza en la reparación.
* **Anvil Alchemy**: El usuario combina dos herraduras forjando una nueva de nivel mayor que las contiene en un porcentaje al azar. Otra vez el usuario puede pagar con HAY reintentos para sacar una mejor combinación.

## Cosmética

Los caballos podrán vestir indumentarios estéticos que serán implementados como NFTs para preservar unicidad/escases de unidades. También será posible bestir al jokey con diferentes NFTs estéticos. Todo esto el usuario podrá usar para aprontar su caballo en el "Pre-parade Ring" antes de inscribirlo en una Carrera.

---

## Carreras

Las carreras son simulaciones deterministas controladas por contratos inteligentes. Cada carrera se define por un tiempo de inicio y una longitud en metros (que determina su duración). A medida que los usuarios inscriben sus caballos, también proporcionan *seeds* que se utilizarán como fuente de aleatoriedad pseudoaleatoria para determinar el desarrollo de la carrera. Estas dos son acciones separadas.

### Etapas de una Carrera

1. **Etapa 0 – Antes de empezar**: Se aceptan inscripciones y seeds de usuarios. Solo se almacenan los últimos 20 seeds recibidos.
2. **Etapa 1 – Carrera en curso**: El primer seed recibido tras la hora de inicio desencadena la carrera. Cada nuevo seed sirve para calcular los movimientos de los caballos, generando un avance iterativo controlado por índices de tiempo discretos. La lógica se asegura de registrar la historia de la carrera de forma progresiva y sin posibilidad de alteración del pasado.
3. **Etapa 2 – Finalizada**: Una vez se alcanza el máximo de seeds o el tiempo final, se cierra la carrera. Se limpian los datos intermedios y se emite un evento con los resultados. Esto setea un estado donde se pueden retirar caballos con sus premios y cobrar apuestas ganadoras.

Los caballos ganadores reciben puntos (no asignados), tokens HAY según su posición y una herradura aleatoria para los primeros puestos. 

---

## Apuestas

El sistema de apuestas permite a los usuarios apostar con dos tokens diferentes, lo que determina las lista de opciones para apostar:

### Apuestas con TLOS

Las apuestas con TLOS serán unicamente a ganador (primer lugar). Esta decisión se debe a que los premios salen de apuestas perdedoras (menos comisión) por lo que no se contaría con volúmenes grandes para cubrir una apuesta de baja probabilidad. Porque tendría que pagar muy fuerte y eso impolicaría sacarle ganancias a otras apuestas para que relativamente tenga sentido apostar dubla o trio.

### Apuestas con HAY

* **Posición**: Acertar la posición exacta (ej. primer lugar).
* **Dupla**: Acertar dos caballos en las posiciones 1 y 2, en ese orden exacto.
* **Trío**: Acertar tres caballos en las posiciones 1, 2 y 3, en ese orden.

En este caso los premios se pagarían con tokens HAY por lo que recurriríamos a la emisión de tokens (generando inflación) por lo que no habría problema en habilitar todas las combinaciones de apuestas porque no competirían entre si por liquidez para premios.

### Resolución de Apuestas

Una vez la carrera finaliza, el contrato de la carrera llama al contrato de apuestas para calcular los valores finales:

* **Total apostado**
* **Total ganadores**
* **Total perdedores**
* **Comisión del sistema (fees)**
* **Total premios** (perdedores - fees)
* **Peso total de las apuestas ganadoras**

El *peso* de cada apuesta ganadora se calcula como la cantidad apostada multiplicada por el inverso de su probabilidad. Por ejemplo, una apuesta a una posición con 1/5 de probabilidad y 10 HAY apostados tiene un peso de 50.

Los premios se reparten proporcionalmente según el peso de cada apuesta. La comisión del sistema se envía a una dirección configurable por el owner del contrato. Si no se ha enviado previamente, se transfiere al momento en que un apostador retira su premio.

---

## Moneda HAY

HAY es una moneda interna del sistema utilizada para:

* Pagar la inscripción de caballos en las carreras.
* Asignar puntos a propiedades de rendimiento o espera.
* comprar puntos no asignados a los caballos.
* Reparar o Combinar herraduras
* Reintentar (randomize) el forjado delos NFTs

El contrato que gestiona HAY no se describe en profundidad aquí, pero su uso es central para la progresión y personalización de los caballos. Es además un OFT

---

## Conclusión

Este sistema combina NFTs, gamificación, aleatoriedad controlada y economía cripto en una experiencia completa de carreras y apuestas. Cada parte del sistema está cuidadosamente diseñada para asegurar transparencia, incentivos correctos y control descentralizado. La interacción entre contratos mantiene la integridad de los resultados y permite a los usuarios interactuar con plena confianza en los mecanismos que determinan tanto el desempeño de sus caballos como la resolución de sus apuestas.
