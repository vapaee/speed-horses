**Introducción**

En el corazón del sistema de carreras de caballos se encuentra el RaceManager, un contrato inteligente cuya misión va mucho más allá de simplemente arrancar un cronómetro. Primero, organiza los fixtures (rondas), agrupando caballos de nivel parecido en bloques de carreras que comparten ventana de inscripción y fecha de inicio, de modo que ninguna prueba quede demasiado desequilibrada. Para dotar de realismo y variabilidad a cada enfrentamiento, mantiene un pool de semillas pseudoaleatorias que se actualiza constantemente: cada nueva semilla se encadena con las anteriores y desplaza la más antigua, garantizando que los resultados no puedan predecirse ni manipularse fácilmente.

Cuando llega la hora de la verdad, el RaceManager simula cada carrera en un número fijo de iteraciones discretas, tomando semillas sucesivas para calcular el avance de cada caballo en cada “tick” y, al término de la prueba, determinar el orden de llegada. Durante el transcurso de la competición —dividida en tres etapas (antes del inicio, en curso y finalizada)— el contrato permite desde simulaciones exploratorias hasta la ejecución definitiva de la función runRace, que va registrando de forma inmutable las semillas usadas y consigna el resultado final.

Paralelamente, el RaceManager se encarga de los costos de inscripción y de la repartición de premios en HAY: cobra en función del nivel de cada caballo, calcula un bote total que combina criterios lineales y logarítmicos, reparte premios principales según posición y añade un “premio por correr” que compensa a los menos favorecidos. Además, coordina la lógica de un contrato externo de apuestas en TLOS, que acumula las apuestas de los usuarios y distribuye un pequeño porcentaje de estos tokens entre los caballos vencedores.

A continuación se presentan con detalle los conceptos clave, su definición y las pautas de implementación en un contrato inteligente.

## 1. Fixtures de carreras

### Definición

Un **Fixture** es un grupo de carreras, próximas entre sí en el tiempo, donde participarán todos (o casi todos) los caballos inscriptos hasta poco tiempo antes del comienzo de la primer carrera. Cada vez que se inscribe un caballo nuevo, se dispara el regenerador del fixture, el cual reagrupará los caballos de nivel similar (que no disten entre sí más de MAX_POINTS_DIFFERENCE_TOLERANCE puntos) para que ningún caballo tenga demasiada ventaja sobre los demás y las carreras queden equilibradas. Esta acción se disparará tras cada nueva inscripción hasta un tiempo fijo considerable (RACE_ROUND_CONFIRM_TIME) antes de comenzar, luego de lo cual se habilitarán las apuestas sobre el fixture ya fijo y confirmado. Cualquier inscripción posterior a este momento, dejará al caballo para la siguiente ronda.

En todo momento se contará con una lista de caballos inscriptos ordenados de menor a mayor seegún sus puntos totales (que hayan obtenido de ganar carreras previas). Cada vez que se reconfigure el fixture, éste tomará entre MIN_HORSES_PER_RACE y MAX_HORSES_PER_RACE de los peores caballos para conformar cada carrera. Esto generará que las primeras carreras del fixture sean de caballos de bajo nivel, dejando para el final las carreras de peso con los mejores caballos. Si ocurre que un caballo inscripto es demasiado bueno con respecto a los demás competidores, quedará sin ser seleccionado para la ronda actual evitando así grandes desbalances. Este caballo quedará imposibilitado de ser retirado de su inscripción (hata que haya suficientes competidores de nivel similar y pueda correr) y en compensación recibirá un premio consuelo (sin correr).

Los Fixtures tendrán una hora de comienzo y distarán del siguiente un tiempo variable que depende de la cantidad de inscriptos en la ronda actual. Si hayb muchos caballos inscriptos, la siguiente ronda será más próxima en el tiempo mientras que si hay pocos inscriptos ésta será más adelante en el tiempo (siempre dentro de los límites FIXTURE_MIN_TIME_DISTANCE y FIXTURE_MAX_TIME_DISTANCE).

El tiempo entre carreras del mismo Fixture será fijo y consideráblemente menor al tiempo entre Fixtures para reforzar el hecho de que pertenecen a la misma ronda. El tiempo que demora cada carrera depende de dos factores que influyen en sentido opuesto. Primero está el nivel del caballo con más cantidad de puntos. A mayor nivel (puntos), más larga será la carrera en longitud, lo cual genera que sea más duradera. En segundo lugar está la cantidad de caballos que corran. A mayor cantidad, más larga la carrera.

### Implementación

* **Estructura**:

  ```solidity
  struct Race {
      uint256[] horses;            // Id de los caballos que corren la carrera
      uint256 level;               // Nivel de la carrear (igual al nivel del mejor caballo)
  }
  struct Fixture {
      uint256 startTime;           // momento de comienzo de la primer carrera a la vez que sirve de ID para el fixture
      bool confirmed;
      uint256[] Race;              // carreras generadas
  }
  uint256[] postponed;             // id de los caballos postergados (por orden de llegada)
  struct Registered {
      uint256 horseId;             // id del caballo
      uint256 raceIndex;           // indice de la carrera a la cual fue asignado. El valor NOT_RACE_ASSIGNED indica que no hay competidopres todavía.
  }
  Registered[] registered;         // caballos que se registraron a tiempo para el próximo Fixture. Están ordenados por nivel.
  ```
* **Inscripción**: función `enterRound(uint256 roundId, uint256 horseId)` que:

  1. Valida que la Ronda no esté confirmada y no haya iniciado.
  2. Cobra el `RACE_HORSE_INSCRIPTION_COST_PER_LEVEL * horse.level()`.
  3. Añade `horseId` a `rounds[roundId].horseIds`.
* **Confirmación**: tras `RACE_ROUND_CONFIRM_TIME` desde `startTime`, se ejecuta `confirmRound(roundId)`, que:

  1. Ordena `horseIds` por nivel.
  2. Divide en subgrupos de hasta `MAX_HORSES_PER_RACE`, asegurando diferencia ≤ `MAX_POINTS_DIFFERENCE_TOLERANCE`.
  3. Crea cada carrera y registra su `raceId` en la Ronda.

---

## 2. Pool de semillas

### Definición

Cola circular que almacena las últimas `MAX_SEED_QUEUE_LENGTH` semillas recibidas. Sirve como fuente de aleatoriedad variable para las simulaciones.

### Implementación

* **Estado**:

  ```solidity
  bytes32[] public seedQueue;
  uint256 public constant MAX_SEED_QUEUE_LENGTH = 100;
  ```
* **Función de agregado** `addSeed(bytes32 userComplementedHash)`:

  1. Combina `userComplementedHash` con la semilla anterior (encadenamiento).
  2. Exige carga de trabajo mínima (por ejemplo, PoW ligero en cliente).
  3. Inserta la nueva semilla al final de `seedQueue`, descartando la más antigua al superar 100.

---

## 3. Simulación de carrera

### Definición

Proceso determinista que, a partir de un índice inicial en el pool de semillas, recorre `TOTAL_RACE_ITERATIONS` iteraciones para calcular el avance acumulado de cada caballo.

### Implementación

* **Parámetros constantes**:

  ```solidity
  uint256 public constant TOTAL_RACE_ITERATIONS = 20;
  ```
* **Función de sólo lectura** `simulateRace(uint256 raceId, uint256 seedIndex) external view returns (uint256[] memory positions)`:

  1. Carga los datos de la carrera (`horseIds`, `length`, etc.).
  2. Para `i` de 0 a `TOTAL_RACE_ITERATIONS - 1`:

     * Obtiene semilla `s = seedQueue[(seedIndex + i) % seedQueue.length]`.
     * Calcula `advance = computeAdvance(horseStats, s, isCurve)` para cada caballo.
     * Acumula en un array de distancias.
  3. Devuelve el orden de llegada según distancias.

---

## 4. Etapas de la carrera

### E1: Pre-inicio

* **Condición**: `block.timestamp < race.start`.
* **Acciones permitidas**:

  * `simulateRace(raceId, seedIndex)` con cualquier `seedIndex`.
  * No modifica estado.

### E2: En curso

* **Condición**: `race.start ≤ block.timestamp < race.start + duration`.
* **Función** `runRace(uint256 raceId)`:

  1. Calcula iteraciones transcurridas `pastTicks` según `block.timestamp`.
  2. Registra en `usedSeedIndices` los índices de semillas aplicadas hasta ahora.
  3. Simula desde `pastTicks` hasta `TOTAL_RACE_ITERATIONS`.
  4. Actualiza `raceResults[raceId]` con posiciones actuales (mutable).

### E3: Finalizada

* **Condición**: `block.timestamp ≥ race.start + duration`.
* **Estado inmutable**:

  * Ya no acepta `runRace`.
  * Permite `withdrawPrize(horseId)` y `claimBetWinnings(bettor)`.

---

## 5. Ejemplo simplificado

* **Pool inicial**: semillas que, al simular repetidamente, arrojan 60 % de victorias para A y 40 % para B.
* **Nueva semilla**: cambia la distribución de resultados.
* Después del inicio, sólo `runRace` fija el primer `seedIndex`, y a medida que entran semillas, se registran índices en `usedSeedIndices` para mantener la reproducibilidad de lo ya ocurrido.

---

## 6. Armado de Rondas

### Definición

Proceso de reorganización de caballos inscritos antes de cada ronda para equidad competitiva.

### Implementación

* En `confirmRound`:

  1. Ordenar `horseIds` ascendentemente por `horse.totalPoints`.
  2. Iterar recogiendo grupos de hasta `MAX_HORSES_PER_RACE`, con diferencia de puntos ≤ `MAX_POINTS_DIFFERENCE_TOLERANCE`.
  3. Caballos sobrantes quedan en la siguiente ronda.
  4. Cada caballo “no elegido” recibe premio consuelo:

     ```plaintext
     consolation = inscriptionCost(horse.level) * HORSE_NOT_CHOSEN_CONSOLATION_PRICE_MULTIPLIER
     ```

---

## 7. Costos y premios en HAY

### Inscripción

* Coste por caballo:

  ```
  RACE_HORSE_INSCRIPTION_COST_PER_LEVEL * horse.level()
  ```

### Fondo de premios

* Nivel de carrera = nivel máximo de los caballos inscritos.
* Total de premios:

  ```
  RACE_TOTAL_PRICE_BASE * bestHorse.totalPoints / bestHorse.level
  ```

### Distribución

1. **Premio por posición**:

   * Caballo en posición P recibe `totalPrice / 2^P`.
2. **Premio por correr**:

   * Promedio de todas las inscripciones:

     ```
     avgInscription = totalInscribedHAY / N
     ```
   * Cada caballo suma `avgInscription` como premio consuelo.

---

## 8. Premios en TLOS

* El contrato de apuestas acumula `totalBets` en TLOS.
* Se deduce un % para premiar a los dos primeros puestos.
* Resto de `totalBets` se distribuye según reglas específicas de apuestas.

---

Con esta estructura, el documento presenta de forma clara y organizada cada uno de los conceptos del Manejador de Carreras, facilitando su comprensión y posterior implementación en Solidity.
