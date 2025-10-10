Introducción

En el corazón del sistema de carreras de caballos se encuentra el RaceManager, un contrato inteligente cuya misión va mucho más allá de simplemente arrancar un cronómetro. Primero, organiza los fixtures (rondas), agrupando caballos de nivel parecido en bloques de carreras que comparten ventana de inscripción y fecha de inicio, de modo que ninguna prueba quede demasiado desequilibrada. Para dotar de realismo y variabilidad a cada enfrentamiento, mantiene un pool de semillas pseudoaleatorias que se actualiza constantemente y que sirven para dar aleatoriedad al resultado de las carreras: cada nueva semilla se encadena con las anteriores y desplaza la más antigua (manteniendo hasta un máximo de **MAX_SEED_QUEUE_LENGTH** valores), garantizando que los resultados no puedan predecirse ni manipularse fácilmente.

Cuando llega la hora de la verdad, el RaceManager simula cada carrera en un número iteraciones discretas que depende de la longitud de la carrera, tomando semillas sucesivas para calcular el avance de cada caballo en cada “tick” (o iteración) y, al término de la prueba, determinar el orden de llegada. Durante el transcurso de la competición el contrato permite desde simulaciones exploratorias hasta la ejecución definitiva de la función `runRace`, que va registrando de forma inmutable las semillas usadas.

Paralelamente, el RaceManager se encarga de los costos de inscripción y de la repartición de premios en HAY: cobra en función del nivel de cada caballo, calcula un bote total que combina criterios lineales y logarítmicos, reparte premios principales según posición y añade un “premio por correr” que compensa a los menos favorecidos. Además, coordina la lógica de un contrato externo de apuestas en TLOS, que acumula las apuestas de los usuarios y distribuye un pequeño porcentaje de estos tokens entre los caballos vencedores.

A continuación se presentan con detalle los conceptos clave, su definición y las pautas de implementación en un contrato inteligente.

## 1. Fixtures de carreras

### Definición

Un **Fixture** es un conjunto de carreras que se desarrollan en momentos cercanos entre sí, con una capacidad máxima de `MAX_FIXTURE_RACES` carreras, organizados en enfrentamientos equilibrados. Cada vez que se inscribe un nuevo caballo, y siempre que el fixture aún tenga cupos disponibles, se activa el algoritmo generador del fixture. Este algoritmo selecciona los caballos elegibles —es decir, aquellos registrados o aplazados— cuyo nivel no difiera en más de `MAX_PERCENT_DIFFERENCE_TOLERANCE` puntos (en el caso de caballos veteranos) o `MAX_LEVELS_DIFFERENCE_TOLERANCE` niveles (para caballos novatos), agrupándolos en carreras donde ninguno tenga una ventaja significativa. Este proceso se repite con cada nueva inscripción admitida hasta alcanzar el umbral de confirmación (`FIXTURE_CONFIRM_TIME`) anterior a la hora de inicio (`fixture.startTime`). A partir de ese momento, el fixture queda fijo, se habilitan las apuestas, y cualquier inscripción posterior será postergada para la siguiente ronda.

Cada fixture tiene una hora de inicio, y la distancia temporal respecto al siguiente fixture varía según la cantidad de caballos inscriptos en el momento de su creación. Si hay muchos inscriptos, el siguiente fixture se programará pronto; si hay pocos, se espaciará más en el tiempo. En todos los casos, este intervalo estará limitado por los valores `FIXTURE_MIN_TIME_DISTANCE` y `FIXTURE_MAX_TIME_DISTANCE`.

El intervalo entre carreras dentro de un mismo fixture es constante (`TIME_BETWEEN_RACES`) y mucho menor que el tiempo entre fixtures, lo que refuerza su pertenencia a una misma ronda. La duración de cada carrera depende de su longitud, que a su vez depende de dos factores: el nivel del caballo con mayor cantidad de puntos (a mayor nivel, mayor longitud de la pista y por ende más duración), y la cantidad de caballos participantes (a mayor número, más larga la carrera).

El contrato mantiene una lista de espera ilimitada de caballos registrados por orden de llegada, así como una lista prioritaria de caballos aplazados —es decir, aquellos que no pudieron competir en fixtures anteriores por falta de rivales adecuados—. Al momento de generar un nuevo fixture, se toman caballos de ambas listas, priorizando los aplazados, hasta completar las carreras necesarias.

El algoritmo de generación de carreras dentro del fixture recorre los caballos candidatos, verificando si existe una carrera en la que puedan participar según su nivel. Si encuentra una carrera adecuada con cupo disponible, lo incorpora; si no, crea una nueva carrera con ese caballo como primer inscripto. Cuando una carrera alcanza el número máximo de participantes, se considera confirmada y, de ser necesario, se comienza una nueva con el mismo nivel. El proceso finaliza cuando se alcanza el número máximo de carreras permitidas en el fixture o se agotan los caballos elegibles. Las carreras que cumplen con el mínimo de participantes se ordenan por nivel y se incorporan al fixture. Los caballos que no logran formar una carrera válida son nuevamente aplazados y reciben un premio consuelo (expresado en token HAY) proporcional a su nivel.

Después de terminada la última carrera, qualquier usuario puede ejecutar la función que da por finalizado el fixture para generar el siguiente fixture, calculando su fecha de inicio en función de la cantidad de caballos en espera. Desde entonces, por cada nueva inscripción, si aún hay cupo, se ejecuta nuevamente el algoritmo generador del fixture. Este ciclo continúa hasta que se alcanza el tiempo de confirmación, tras lo cual el fixture queda congelado y sólo se siguen acumulando inscripciones para la siguiente ronda.

Si un caballo que corrió en la última carrera de un fixture, es retirado de la misma, se ejecutará automáticamente la función que dará por finalizado el fixture y generará el siguiente.

### Implementación

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RaceManager {
    // Structs
    struct Race {
        // datos iniciales de la carrera fijos en todo momento
        uint256[] horses;            // Id de los caballos que corren la carrera
        uint256 length;              // Longitud de la carrera en metros
        uint256 level;               // Nivel de la carrear (igual al nivel del mejor caballo)
        uint256 startTime;           // momento de comienzo de la carrera.
        uint256 iteratios;           // cantidad de iteraciones que llevará completar la carrera (depende de su longitud)
        // datos dinámicos que se iran actualizando tras cada iteracción
        bytes32[] seeds;             // Semillas correspondientes a tiempo pasado
        // Datos finales que se escribirán una única vez
        uint256[] positions;         // es el resultado de la carrera. En el índice 0 está el id del ganador.
    }

    struct Fixture {
        uint256 startTime;           // momento (timestamp) de comienzo de la primer carrera a la vez que sirve de ID para el fixture
        uint256[] Race;              // carreras generadas. Las carreras de un fixture se identifican por su índice en esta lista
        uint256 currentRace;         // índice de la carrera siguiente o en curso.
        uint256 prevFixture;         // referencia al Fixture anterior. Servirá para borrar datos de Fixtures pasados.
    }

    struct Postponed {
        uint256 horseId;             // id del caballo
        uint256 price;               // cantidad en HAY que puede cobrar el dueño del caballo por concepto de premio consuelo
    }

    // State
    Postponed[] postponed;           // id de los caballos postergados (por orden de llegada)
    uint256[] registered;            // id de los caballos inscriptos
    
    mapping(uint256 => Fixture) public fixtures; // key is the startTime of the fixture
    uint256 currentFixture;          // id del fixture en el que trabajamos actualemnte. Puedes no haber empezado o estar en proceso.
```
* **Creación de un Fixture**: `createNextFixture()`
  Se ejecuta cuando un caballo de la última carrera del fixture actual es retirado. Esta función decide el startTime del siguiente Fixture basándose en la cantidad de caballos que esperan. Actualiza la variable `current = startTime` para finalmente ejecutar `regenerateFixture(current)` para generar la primer versión del fixture.

```solidity
    // Create next fixture when last race is completed
    function createNextFixture() external {
        // determine next startTime based on waiting list length
        uint256 nextStart = block.timestamp + computeInterval();
        currentFixtureId = nextStart;
        fixtures[nextStart].startTime = nextStart;
        regenerateFixture(nextStart);
    }
```
* **Regenerar Fixture**: `regenerateFixture(uint256 fixtureId)`
  función que regenera el current fixture, barriendo los postrgados primero y los registrados después para ubicar a los caballos en carreras con otrs caballos de nivel similar hasta completar el máximo de carreras o procesar todos los caballos en espera.

```solidity
    // Regenerate current fixture grouping eligible horses
    function regenerateFixture(uint256 fixtureId) public {
        // Iterate postponed then registered to assign into races
        // respecting MAX_FIXTURE_RACES and level tolerances
        // ...implementation details...
    }
```
* **Inscripción**: `registerHorse(uint256 horseId)`
  1. Se cobra el Costo de Inscripción que depende de su nivel: `RACE_HORSE_INSCRIPTION_COST_PER_LEVEL * horse.level()`.
  2. Añade `horseId` al final de `registered`.
  3. Si el fixture no está lleno y no empezó todavía, se corre `regenerateFixture(fixtureId)`
  
```solidity
    // Register a new horse
    function registerHorse(uint256 horseId) external { /* … */ }

    // Helpers (stubs)
    function computeInterval() internal view returns (uint256) { /* … */ }
    function getHorseLevel(uint256) internal view returns (uint256) { /* … */ }
    
    uint256 public constant RACE_HORSE_INSCRIPTION_COST_PER_LEVEL = 1e18;
    uint256 public constant HORSE_NOT_CHOSEN_CONSOLATION_PRICE_MULTIPLIER = 1;
    uint256 public constant FIXTURE_CONFIRM_TIME = 10 minutes;
}
```

## 2. Simulación de carreras

### Definición

Dado que el tiempo de la carrera se representa de forma discreta, dividiéndolo en `race.iterations` partes, cada iteración corresponde al avance de los caballos en un tramo determinado. Para simular el desarrollo de una carrera, el contrato ofrece dos funciones de solo lectura que pueden ejecutarse en cualquier momento utilizando el pool de semillas disponible. Además, existe una tercera función que efectivamente corre la carrera y registra su evolución para que se mantenga inalterable en futuras simulaciones.

Antes de que la carrera comience, es posible simularla de dos maneras: utilizando la última semilla del pool como punto de partida, o indicando explícitamente el índice de la semilla inicial a usar. A partir de esa primera semilla, las sucesivas se determinan calculando el índice siguiente con base en la semilla utilizada en la iteración anterior. De este modo, la elección de la semilla inicial define completamente la secuencia de la carrera simulada.

Una vez iniciada la carrera (`block.timestamp > race.startTime`), se habilita la función encargada de ejecutarla realmente. Esta función calcula cuántas iteraciones ("ticks") deberían haberse procesado desde la última ejecución, en función del tiempo transcurrido. Luego, simula el avance correspondiente desde el punto donde se había detenido, utilizando las semillas disponibles en el estado actual del pool. Las semillas utilizadas pero aún no registradas se agregan al historial `race.seeds` generando úna selección de semillas que deberán respetarse en sucesivas simulaciones.

De este modo, en las simulaciones que se realicen una vez iniciada la carrera, se tomará primero el historial de semillas ya registrado (`race.seeds`) y, una vez agotado, se continuará con nuevas semillas generadas a partir de la última semilla utilizada. Esto garantiza que cualquier semilla agregada durante el transcurso de la carrera solo influya en iteraciones futuras, preservando inalteradas las iteraciones ya registradas.

**Pista y sus tramos**

La pista sobre la cual corren los caballos tiene una estructura geométrica similar a una pista de atletismo: un rectángulo con semicírculos en los extremos. El rectángulo tiene un largo total de `4R`, y cada semicírculo tiene radio `R`, lo que implica que cada recta mide `2R` y cada curva equivale a un arco de longitud `πR`. El punto de inicio (y final) de la carrera se ubica al comienzo de la primera curva, en sentido antihorario, es decir, justo al final de la segunda recta.

Como los caballos se comportan de manera distinta en rectas y curvas, es esencial saber en qué tramo de la pista se encuentran durante cada iteración para calcular correctamente su avance. Este comportamiento diferencial requiere conocer no solo el punto actual del recorrido, sino también el punto de partida de la carrera (el *offset* de inicio), ya que todas las carreras terminan siempre en el mismo lugar: al finalizar la segunda recta. La pista completa tiene una longitud total de `TOTAL_TRACK_LENGTH` metros.

El largo de cada carrera depende de dos factores: la cantidad de caballos inscriptos y el nivel del caballo con mayor puntaje. La distancia total se calcula tomando `TOTAL_TRACK_LENGTH` como valor máximo posible (una vuelta completa a la pista) y dividiéndolo en tres tercios, cada uno determinado por distintas condiciones:

1. **Primer tercio**: siempre se incluye completamente, asegurando una longitud mínima de `TOTAL_TRACK_LENGTH / 3` para cualquier carrera.
2. **Segundo tercio**: se incluye parcialmente, en un porcentaje que depende del número de caballos inscriptos. Se calcula así:
   `(TOTAL_TRACK_LENGTH / 3) * ((race.horses.length - MIN_HORSES_PER_RACE) / (MAX_HORSES_PER_RACE - MIN_HORSES_PER_RACE))`.
3. **Tercer tercio**: también se agrega parcialmente, en función del nivel del mejor caballo de la carrera. Se calcula como:
   `(TOTAL_TRACK_LENGTH / 3) * (min(MAX_HORSE_LEVEL_TRACK_MODIFIER, bestHorse.level) / MAX_HORSE_LEVEL_TRACK_MODIFIER)`.

Esta fórmula asegura que cuanto mayor sea el nivel del caballo líder y mayor la cantidad de participantes, más extensa será la carrera, hasta un máximo de una vuelta completa.

### Implementación

```solidity
    // View-only: simula la carrera completa sin alterar estado
    function simulateRace(
        uint256 fixtureId,
        uint256 raceIndex
    ) external view returns (uint256[] memory finalPositions) { /* … */ }

    // View-only: simula desde una iteración dada
    function simulateRaceFrom(
        uint256 fixtureId,
        uint256 raceIndex,
        uint256 startIteration
    ) external view returns (uint256[] memory positions) { /* … */ }

    // Ejecutable: corre la simulación real acumulando semillas
    function runRace(
        uint256 fixtureId,
        uint256 raceIndex
    ) external { /* … */ }

    function getRaceLength(
        uint256 fixtureId,
        uint256 raceIndex
    ) internal view returns (uint256) { /* … */ }
        
```

## 3. Pool de semillas

### Definición
El sistema de carreras utiliza una cola de semillas con una capacidad máxima de `MAX_SEED_QUEUE_LENGTH`. Estas semillas alimentan el algoritmo de pseudoaleatoriedad encargado de resolver las carreras, donde hay dinero en juego, por lo que resulta fundamental evitar que una sola persona pueda controlar por completo su contenido. Si alguien lograra introducir todas las semillas del pool, podría predecir o manipular los resultados, afectando la integridad del sistema. Para prevenir esto, el algoritmo de incorporación de nuevas semillas impone dos mecanismos de protección: primero, las semillas se encadenan entre sí, de modo que cada nueva semilla depende de las anteriores, lo que garantiza que incluso un conjunto completo de semillas recientes esté influenciado por el historial previo; y segundo, las semillas no son proporcionadas directamente por los usuarios, sino que el sistema les entrega la última semilla disponible, la cual deben combinar con un valor aleatorio para generar un hash que cumpla con la condición de ser menor a `SEED_HASH_THRESHOLD`. Esto introduce una pequeña exigencia computacional del lado del cliente, haciendo inviable la carga masiva de semillas precalculadas con la intención de manipular el resultado de la carrera.

### Implementación

* **Estado**:

  ```solidity
  struct SeedEntry {
    bytes32 seed;              // semilla generada
    uint256 timestamp;         // momento en que ingresó a la cola
  }
  bytes32[] public seedQueue;  // lista de las últimas MAX_SEED_QUEUE_LENGTH semillas
  ```
* **Función de agregado** `addSeed(bytes32 seedUsed, bytes32 random)`:
  2. Verifica que seedUsed está entre las últimas semillas que tengan un timestamp reciente (no mayor a `SEED_TIME_THRESHOLD`)
  2. Combina `seedUsed` con `random` para calcular su hash y verificar que efectivamente es menor que `SEED_HASH_THRESHOLD`
  3. Combina las últimas `SEED_CHAIN_LENGTH` semillas de la cola con el número `random` para generar el nuevo seed que se coloca al final de la cola.
  4. Si hay una carrera en curso, se ejecuta `runRace()` para procesar las iteraciones que no se hayan procesado aún, habiendo incorporado la nueva semilla.

---

## Costos y Premios en HAY

Cada caballo que se inscribe debe abonar un coste en tokens HAY proporcional a su nivel, calculado como

```solidity
inscriptionCost = RACE_HORSE_INSCRIPTION_COST_PER_LEVEL × horse.level()
```

Este importe se acumula en el pool de cada carrera, que sólo se abre una vez haya entre MIN\_HORSES\_PER\_RACE y MAX\_HORSES\_PER\_RACE participantes. El nivel de la carrera lo determina el caballo de mayor nivel, y el bote total de premios se define combinando criterios lineales y logarítmicos:

```solidity
totalPrize = RACE_TOTAL_PRICE_BASE × bestHorse.totalPoints ÷ bestHorse.level
```

A continuación, el reparto principal se hace según la posición de llegada P, de modo que cada caballo recibe

```solidity
positionPrize = totalPrize ÷ (2^P)
```

Así, el ganador obtiene la mitad del bote, el segundo la cuarta parte, el tercero la octava, y así sucesivamente; el remanente `totalPrize ÷ (2^N)` (donde N es el número de participantes) queda sin repartir.

Para garantizar que todos los corredores perciban algún retorno, se añade además un premio de participación calculado como el promedio de los costes de inscripción:

```solidity
participationPrize = (suma de todos los inscriptionCost) ÷ N
```

De este modo, los caballos de menor nivel suelen cobrar más de lo que pagaron, ya que sus rivales aportaron sumas mayores; en cambio, si un caballo de alto nivel queda último, puede recibir menos de lo que abonó, pues el premio de participación resulta inferior a su inscripción.

Si un caballo es demasiado superior y no encaja en ningún grupo equilibrado, no correrá en ese fixture: permanece inscrito para las rondas siguientes y, por cada ciclo en que quede fuera, recibe un premio consuelo igual a

```solidity
inscriptionCost × HORSE_NOT_CHOSEN_CONSOLATION_PRICE_MULTIPLIER
```

funcionando a la vez como una forma de “staking” del caballo hasta que pueda competir.

Las apuestas en TLOS se gestionan en un contrato independiente: tras cerrarse la inscripción, todos los tokens totalBets apostados se acumulan y, una vez concluida la carrera, se destina un porcentaje prefijado para premiar a los dos primeros puestos; el resto de lo recaudado se canaliza según las reglas internas de ese contrato de apuestas.

---

## Premios en TLOS

Existe un contrato aparte que recibe las apuestas de los usuarios en TLOS. Cada carrera acumula un total de `totalBets` tokens TLOS, de los cuales:

* Un pequeño porcentaje se destina a premiar a los dos primeros puestos.
* El remanente se mantiene como fondo de la casa o se redistribuye según reglas de gobernanza.

En el momento que un caballo es retirado de una carrera terminada, se  notifaica al contrato de apuestas que la carrera ha terminado pasando el resultado como parámetro, lo cual genera que ese contrato transfiera un porcentaje fijo de los tokens TLOS de las apuestas perdedoras que se usarán en ese mismo contrato papra pagar a los ganadores. Ese porcentaje transferido al RaceManager es usado para pagar a los dos primeros puestos de la carrera en TLOS, donde el primero recibe dos tercios del total y el segundo un tercio.
