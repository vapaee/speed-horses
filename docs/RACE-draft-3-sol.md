**Introducción**

En el corazón del sistema de carreras de caballos se encuentra el RaceManager, un contrato inteligente cuya misión va mucho más allá de simplemente arrancar un cronómetro. Primero, organiza los fixtures (rondas), agrupando caballos de nivel parecido en bloques de carreras que comparten ventana de inscripción y fecha de inicio, de modo que ninguna prueba quede demasiado desequilibrada. Para dotar de realismo y variabilidad a cada enfrentamiento, mantiene un pool de semillas pseudoaleatorias que se actualiza constantemente: cada nueva semilla se encadena con las anteriores y desplaza la más antigua (manteniendo ahsta un máximo de `MAX_SEED_QUEUE_LENGTH` valores), garantizando que los resultados no puedan predecirse ni manipularse fácilmente.

Cuando llega la hora de la verdad, el RaceManager simula cada carrera en un número fijo de iteraciones discretas, tomando semillas sucesivas para calcular el avance de cada caballo en cada “tick” (o iteración) y, al término de la prueba, determinar el orden de llegada. Durante el transcurso de la competición el contrato permite desde simulaciones exploratorias hasta la ejecución definitiva de la función runRace, que va registrando de forma inmutable las semillas usadas.

Paralelamente, el RaceManager se encarga de los costos de inscripción y de la repartición de premios en HAY: cobra en función del nivel de cada caballo, calcula un bote total que combina criterios lineales y logarítmicos, reparte premios principales según posición y añade un “premio por correr” que compensa a los menos favorecidos. Además, coordina la lógica de un contrato externo de apuestas en TLOS, que acumula las apuestas de los usuarios y distribuye un pequeño porcentaje de estos tokens entre los caballos vencedores.

A continuación se presentan con detalle los conceptos clave, su definición y las pautas de implementación en un contrato inteligente.

## 1. Fixtures de carreras

### Definición

Un **Fixture** es un grupo de carreras, próximas entre sí en el tiempo, donde participarán hasta un máximo de `MAX_FIXTURE_HORSES` caballos agrupados en carreras competitivas. Cada vez que se inscribe un caballo nuevo, si todavía hay cupos en el fixture, se dispara el regenerador del fixture, el cual tomará los caballos elegibles (registrados y pospuestos) que tengan un nivel similar (que no disten entre sí más de MAX_POINTS_DIFFERENCE_TOLERANCE puntos (para caballos veteranos) o MAX_LEVELS_DIFFERENCE_TOLERANCE de niveles (para caballos novetos)) y los agrupará en carreras equilibradas donde ningún caballo tiene demasiada ventaja sobre los demás. Esta acción se disparará tras cada nueva inscripción que quepa en el fixture hasta un tiempo fijo considerable (FIXTURE_CONFIRM_TIME) antes de comenzar (`fixture.startTime`), luego de lo cual se habilitarán las apuestas sobre el fixture ya fijo y confirmado. Cualquier inscripción posterior a este momento, dejará al caballo aplazado para la siguiente ronda.

Los Fixtures tendrán una hora de comienzo y distarán del siguiente fixture un tiempo variable que depende de la cantidad de inscriptos al momento de definir el comienzo del siguiente fixture. Si hay muchos caballos inscriptos, la siguiente ronda será más próxima en el tiempo mientras que si hay pocos inscriptos ésta será más adelante en el tiempo (siempre dentro de los límites `FIXTURE_MIN_TIME_DISTANCE` y `FIXTURE_MAX_TIME_DISTANCE`).

El tiempo entre carreras del mismo Fixture será fijo (`TIME_BETWEEN_RACES`) y consideráblemente menor al tiempo entre Fixtures para reforzar el hecho de que pertenecen a la misma ronda. El tiempo que demora cada carrera depende directamente de su longitud, la cual depende de dos factores. Primero está el nivel del caballo con más cantidad de puntos. A mayor nivel (puntos), más larga será la carrera en longitud, lo cual genera que sea más duradera. En segundo lugar está la cantidad de caballos que corran. A mayor cantidad, más larga la carrera.

El contrato mantiene una cola de espera ilimitada de caballos registrados por orden de llegada. Al mismo tiempo, se mantiene una lista con los caballos que hayan sido aplazados en algún fixture anterior por no tener suficientes competidores de nivel similar. Al generar un nuevo fixture, se extraen de ambas listas tantos caballos como se requiera para generar las carreras del fixture, priorizando a los aplazados. Una vez terminado el fixture, aquellos caballos para los que no se encontraron rivales adecuados para ese fixture pasan automáticamente a la lista de aplazados.

El algoritmo que crea el fixture debe recorrer los caballos que se van a intentar ubicar en alguna carrera y verificar si ya existe una carrera apta para cada caballo, comprobando que el nivel del nuevo caballo no difiera demasiado del de los caballos que ya participan en esa carrera. Si la carrera aún tiene espacio y el caballo reúne los requisitos, se incorpora a ella. En caso de que no exista una carrera adecuada para ese nivel, se crea una nueva con ese caballo como primer participante. Asimismo, si ya existe una carrera que ha alcanzado el número máximo de caballos, esa carrera se consolida como confirmada y se genera una nueva con el mismo nivel, pero únicamente con el nuevo caballo. Si se alcanza el máximo de carreras por fixture o ya se procesaron todos los caballos que estaban esperando se concidera terminado el proceso. Todas las carreras generadas que cumplen con tener el mínimo de caballos, se las ordena por nivel y se las incorpora al fixture. Aquellos caballos que hayan quedado con carreras que no cumplen el mínimo, serán aplazados con un premio consuelo que depende de su nivel.

Cuando un caballo es retirado de la última carrera de un fixture, este último se da por terminado y se genera el siguiente fixture decidiendo además su fecha de comienzo basándose en la cantidad de caballos que esperan. Posteriormente, por cada nuevo caballo inscripto, si el fixture no está lleno, se corre el algoritmo de generación del Fixture otra vez. Esto se repite hasta que pasa el tiempo de confirmación, lo que generará que el fixture no sufra más cambios y sólo se acumulen caballos registrados.

### Implementación

* **Estructura**:

  ```solidity
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
      uint256[] positions;         // es el resultado de la carrera. Enm el índice 0 está el id del ganador.
  }
  struct Fixture {
      uint256 startTime;           // momento de comienzo de la primer carrera a la vez que sirve de ID para el fixture
      uint256[] Race;              // carreras generadas. Las carreras de un fixture se identifican por su índice en esta lista
      uint256 currentRace;         // índice de la carrera siguiente o en curso.
  }
  struct Postponed {
      uint256 horseId;             // id del caballo
      uint256 price;               // cantidad en HAY que puede cobrar el dueño del caballo por concepto de premio consuelo
  }
  Postponed[] postponed;           // id de los caballos postergados (por orden de llegada)
  uint256[] registered;            // id de los caballos inscriptos
  
  mapping(uint256 => Fixture) public fixtures; // key is the startTime of the fixture
  uint256 current;                 // id del fixture en el que trabajamos actualemnte. Puedes no haber empezado o estar en proceso.
  ```

* **Creación de un Fixture**: `createNextFixture()`
  Se ejecuta cuando el un caballo de la última carrera del fixture actual es retirado. Esta función decide el startTime del siguiente Fixture basándose en la cantidad de caballos que esperan. Actualiza la variable `current = startTime` para finalmente ejecutar `regenerateFixture(current)` para generar la primer versión del fixture.

* **Regenerar Fixture**: `regenerateFixture(uint256 fixtureId)`
  función que regenera el current fixture, barriendo los postrgados primero y los registrados después para ubicar a los caballos en carreras con otrs caballos de nivel similar hasta completar el máximo de carreras o procesar todos los caballos en espera.

* **Inscripción**: `registerHorse(uint256 horseId)`
  1. Se cobra el Costo de Inscripción que depende de su nivel: `RACE_HORSE_INSCRIPTION_COST_PER_LEVEL * horse.level()`.
  2. Añade `horseId` al final de `registered`.
  3. Si el fixture no está lleno y no empezó todavía, se corre `regenerateFixture(fixtureId)`
  
---

## 2. Simulación de carrera

### Definición

* **Simulación y ejecución de las carreras**

Dado que estamos representando el tiempo de forma discreta dividiendo el tiempo total de la carrera en `race.iteratios` partes, en cada iteración lo que estamos averiguando es el avance de los caballos para ese tramo de tiempo. Existen dos funciones de sólo lectura que se pueden ejecutar en cualquier momento para simular la carrera con el pool de semillas en ese momento y una tercera que efectivamnte corre la carrera y guarda el avance hasta el momento.

Antes de comenzar la carrera, éstas pueden ser simuladas de dos formas. Una es usando la última semilla para la primera iteración y la segunda forma es pasando por parámetro el índice de la semilla que se quiere usar como arranque. Luego, en ambas funciones, para sucesivas iteraciones se calcula el índice de la siguiente semilla a partir de la semilla de la iteración anterior. Es decir, que la elección de la primera semilla determinará el desarrollo de toda la carrera.

Luego, existe la función para efectivamente correr la carrera, la cual sólo se puede ejecutar una vez iniciada la carrera (block.timestamp > race.startTime). Esta función lo que hace es verificar cuanto tiempo ha pasado desde la última ejecución y calculando cuantos "ticks" corresponden a tiempo pasado y que no hayan sido procesados y almacenados aun. Para eso, simulará la carrera desde el último punto registrado hasta al momento actual, tomando semillas del pool en el estado en que se encuentre. Esto modificará la lista de `race.seeds` agregando las semillas que hayan sido usadas para la simulación y no hayan sido registradas aun. En posteriores ejecuciones de las funciones de sólo lectura que simulan la carrera, se tomará en cuenta el historial de la carrera `race.seeds` para las primeras iteraciones para luego completar con semillas tomadas de calcular el siguiente índice a partir de la última semilla usada. Esto provocará que cada semilla que pueda ingresar durante el desarrollo de la carrera, sólo afecte las iteraciones futuras manteniendo inmutable las iteraciones pasadas.

* **Pista y sus tramos**

La estructura geométrica de la pista sobre la cual van a correr los caballos es similar a una pista de atletismo; es decir, un rectángulo (cuyo bounding box tiene un largo de 4R) con semicírculos en los extremos (cuyo radio es R). Es decir que las rectas miden 2R mientras que la curva mide PI*R. El punto cero (y final) de la carrera se encuentra al comienzo de la primera curva (o final de la segunda recta) en sentido antihorario. Dado que los caballos se mueven de forma distinta si están en una curva o en una recta, es necesario saber en qué punto de la carrera se encuentran para determinar si corresponde a una recta o a una curva.

Las carreras tienen una lingitud que depende de la cantidad de caballos inscriptos y de el nivel del mejor caballo. Dado que las carreras siempre termian el el mismo punto de la pista (al terminar la segunda recta) y que el largo total de la pista es de TOTAL_TRACK_LENGTH metros. Es necesario saber en que punto de la pista arranca (cual es el offset de arranque) para saber si en una iteración estamos atrvezando una curva o una recta porque los caballos reaccionan (avanzan) de forma diferente.

Para determinar el largo de la carrera (cuya cota superior es TOTAL_TRACK_LENGTH, es deicr, una vuelta entera) tenemos que dividir TOTAL_TRACK_LENGTH en tres partes que serán tratadas de forma difernete. El premer tercio va entero siempre, asegurando un minimo de TOTAL_TRACK_LENGTH/3 de largo a la carrera más corta. Luego el segundo tercio será agregado en un porcentaje de 0% a 100% dependiendo de la cantidad de caballos. Es decir (TOTAL_TRACK_LENGTH/3) * ((race.horses.length-MIN_HORSES_PER_RACE) / (MAX_HORSES_PER_RACE - MIN_HORSES_PER_RACE)). Luego el tercer tercio será agregado en un porcentaje de 0% a 100% dependiendo del nivel del caballo más alto (con una cota de MAX_HORSE_LEVEL_TRACK_MODIFIER). Es deicr, (TOTAL_TRACK_LENGTH/3) * (Math.min(MAX_HORSE_LEVEL_TRACK_MODIFIER, bestHorse.level)) / MAX_HORSE_LEVEL_TRACK_MODIFIER.

### Implementación

TODO: llenar con estructuras y firmas de las funciones necesarias. Debe haber un preve explicativo de cómo debería ser el algoritmo cuando se liste una función.

---

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
  3. Combina las últimas `SEED_CHAIN_LENGTH` semillas de la cola y las combina con `random` para generar el nuevo seed que se coloca al final de la cola.
  4. Si hay una carrera en curso, 

---


Costos y Premios en HAY
- Cada caballo debe pagar su inscripción con el token HAY, un monto que depende de su nivel. A mayor nivel, más paga. Costo de inscripción = RACE_HORSE_INSCRIPTION_COST_PER_LEVEL * horse.level()
- Al formarse una carrera con un mínimo de MIN_HORSES_PER_RACE y másximo de MAX_HORSES_PER_RACE, el nivel de la carrera será el nivel del caballo que tenga nivel más alto. El monto total en premios para las posiciones aumentará cuanto más alto sea los puntosnque tenga el caballo, en una proporción intermedia entre lineal y logarítmica. Es decir total_price = RACE_TOTAL_PRICE_BASE * better_horse.total_points / better_horse.level
- Premio por ganar. Cada carrera paga un total de HAY menor a total_price donde cada caballo que obtiene la posición P termina ganando total_price / (2^P). Es decir, el primero se lleva total_price/2, el segundo se lleva total_price/4, el tercero total_price/8 y así sicesivamente. Sobrando un total_price/(2^N) que no se paga. Es decir, el premio que se paga suma un total de total_price - total_price/(2^N) siendo N la cantidad de caballos que corren.
- Premio por correr. Cuando N caballos corren una carrera, se calcula cuanto es el total de tokens HAY que se recaudó por concepto de inscripción. Luego se calcula el promedio sumando todo eso y dividiendo por N. Cada caballo entonces cobrará su premio por la posición que obtenga en la carrera más un premio consuelo que es ese promedio. Esto generará que los peores caballos (dentro de una carrera) tiendan a cobrar más de lo que gastaron en inscribirse porque los caballoss que le ganaron son mejores y pagaron más. Sin embargo, si un buen caballo (que paga relativamente más) termina en último lugar, terminará cobrando menos de lo que pagó para inscribirse pues el premio consuelo (que es un promedio) es menor a lo que pagó.
- puede ocurrir que si un caballo es demasiado bueno y no tiene competidores, no será elegino para formar parte de la Fixture actual y por tanto no correrá ni podrá ser retirado. Quedará inscripto hasta que se le asigne una carrera en futuras Fixtures. Por cada Fixture que un caballo quede fuera de la selección y se lo posponga para otra Fixture, se le pagará un premio consuelo equivalente a el costo de inscripción * HORSE_NOT_CHOSEN_CONSOLATION_PRICE_MULTIPLIER unidades del token HAY. Es decir, será proportional al coste de inscripción. es una manera de poner en staking a tu caballo canador.

Premios en TLOS
existe un contrato aparte que recibe las apuestas de los apostadores sobre caballos en una carrera. Cada carrera entonces recibirá por concepto de apuestas un total de total_bets de tokens TLOS que se repartiran entre los ganadores. Todo lo recaudado que no tenga un ganador, será lo que se use para premios. De esa cantidad extraeremos un porcentaje para poremiar los dos primeros puestos. 
