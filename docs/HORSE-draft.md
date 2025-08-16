## Entidad: Caballo

El contrato **CaballoNFT** extiende el estándar ERC-721 para representar cada caballo como un token no fungible y, a su vez, incorporar toda la lógica necesaria para gestionar atributos (“stats”), tiempos de espera independientes y progresión de nivel dentro de nuestro sistema de carreras y mejoras.

### 1. Variables y estructura de datos

> **Contexto:** Cada caballo necesita almacenar por un lado sus atributos de desempeño, por otro lado dos esperas independientes (alimentación y descanso) y además llevar la cuenta de puntos que ha ganado y repartido. Para ello definimos:

1. **Stats de desempeño** (`uint256` cada uno):

   * `acceleration`  // puntos de aceleración
   * `stamina`       // puntos de resistencia
   * `minSpeed`      // puntos de velocidad mínima
   * `maxSpeed`      // puntos de velocidad máxima
   * `luck`          // puntos de suerte (bonus aleatorio)
   * `curveBonus`    // puntos extra en curvas
   * `straightBonus` // puntos extra en rectas

2. **Stats de espera** (`uint256` cada uno, inicial 0):

   * `raceCooldownStat` // al aumentar, *reduce* el tiempo de espera entre carreras
   * `feedCooldownStat` // al aumentar, *reduce* el tiempo de espera tras asignar puntos

3. **Timestamps de finalización de esperas** (`uint256` cada uno):

   * `restFinish` // instante (timestamp) a partir del cual el caballo puede inscribirse de nuevo
   * `feedFinish` // instante (timestamp) a partir del cual el caballo puede transferirse o inscribirse

4. **Puntos de progresión** (`uint256`):

   * `pointsUnassigned` // puntos obtenidos en carreras pero aún no repartidos
   * `pointsAssigned`   // puntos ya asignados a stats

---

### 2. Cálculo de avance en carrera

> **Contexto:** Para simular cada “paso” de la carrera, necesitamos calcular cuánto avanza un caballo según sus stats y una semilla aleatoria, y en qué momento de la carrera nos encontramos. Para todos los cálculos que se van a realizar acá se usará la biblioteca UD60x18.
```solidity
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
```
La firma de la función es:

```solidity
function advanceHorse(
    uint256 id,           // id del caballo que avanza
    bytes32 rand,         // número aleatorio
    bool isRect,          // indica si estamos doblando una curva
    uint256 length,       // longitud de la carrera
    uint256 tick          // número de iteración (entre 0 y TOTAL_RACE_ITERATIONS-1 pasos o ticks que tiene la carrera)
) public view returns (uint256)
```  

* **Qué hace:**

  1. Lee los stats de desempeño (`acceleration`, `stamina`, etc.) del caballo `id`.
  2. Combina esos valores con la semilla `rand` en un algoritmo (por ejemplo, mezclando y normalizando).
  3. Devuelve un `uint256` que representa la distancia o avance logrado en este “tick” de simulación.

* **Algoritmo:**

  1. Stats: 
    Dado que lo que tiene el caballo son propiedades que acumulan puntos asignados, no sabemos todavía cuál es el valor real con el que debemos operar en el algoritmo. Para empezar, todas las propiedades arrancan en cero y comienzan a aumentar a medida que el usuario asigna puntos a dicha propiedad. Esa propiedad va acumulando los puntos de forma lineal, pero el resultado que determina en qué nivel se encuentra la propiedad será logarítmico. Es decir, el nivel de la propiedad es el logaritmo (sin truncar usando UD60x18) del valor de la propiedad.

    Por lo tanto, en la etapa de recuperación de los stats del caballo, lo primero que tenemos que hacer es averiguar cuál es el nivel actual real de cada propiedad. Luego, esa magnitud se transforma en un valor utilizable (por ejemplo al multiplicase por una constante) para finalmente obtener el valor final que impactará de forma directa en el avance del caballo, ya sea añadiendo o recortando.

  2. 
    * `minSpeed`
      La velocidad mínima es una cantidad que se suma al final del cálculo de lo avanzado, independientemente de los stats del caballo.

      ```pseudocode
      // Calculamos el nivel real de la propiedad minSpeed
      minSpeedLevel = log2(minSpeed)
      // Multiplicamos por la constante de escala
      minSpeedBonus = minSpeedLevel * MIN_SPEED_BASE_VALUE
      // minSpeedBonus queda listo para sumarlo al avance final
      ```

    * `luck`
      La suerte es un concepto abstracto que agrega un bonus pseudoaleatorio al avance, proporcional al nivel de luck.

      ```pseudocode
      // Nivel real de la propiedad luck
      luckLevel = log2(luck)

      // Generamos un valor pseudoaleatorio para luck,
      // por ejemplo con keccak256(rand, LUCK_ENUM)
      randomLuck = pseudoRandom(rand, LUCK_ENUM)  

      // Tomamos un porcentaje <100
      percentLuck = randomLuck % 100

      // Bonus de avance por suerte
      luckBonus = percentLuck * LUCK_SPEED_PER_LEVEL * (luckLevel + LUCK_MIN_POINTS)
      ```

    * `curveBonus`
      Igual que luck, pero sólo en curvas (`!isRect`), usando otro enumerado para variar el seed.

      ```pseudocode
      // Reutilizamos lógica de luck con CURVE_ENUM
      curveLevel = log2(curveBonusProperty)

      randomCurve = pseudoRandom(rand, CURVE_ENUM)

      percentCurve = randomCurve % 100

      curveBonusValue = percentCurve * CURVE_SPEED_PER_LEVEL * (curveLevel + CURVE_MIN_POINTS)
      ```

    * `straightBonus`
      Igual que luck, pero sólo en rectas (`isRect`), con su propio enumerado.

      ```pseudocode
      // Reutilizamos lógica de luck con STRAIGHT_ENUM
      straightLevel = log2(straightBonusProperty)

      randomStraight = pseudoRandom(rand, STRAIGHT_ENUM)

      percentStraight = randomStraight % 100

      straightBonusValue = percentStraight * STRAIGHT_SPEED_PER_LEVEL * (straightLevel + STRAIGHT_MIN_POINTS)
      ```

    * `maxSpeed`
      En cada iteración, los caballos avanzan una cantidad que depende de sus states. Esa cantidad representa la velocidad que tiene el caballo en ese momento (o su avance). Si, una vez calculado el nivel básico de velocidad del caballo, este supera la velocidad máxima del mismo, entonces dicho valor se ve truncado por este máximo.

      ```pseudocode
      // Calculamos el avance hasta el momento
      calculatedAdvance = minSpeedBonus + luckBonus + curveBonusValue + straightBonusValue

      // Nivel real de la propiedad maxSpeed
      maxSpeedLevel = log2(maxSpeed)

      // Umbral de velocidad: constante + nivel
      maxSpeedThreshold = (MAX_SPEED_EXTRA_POINTS + maxSpeedLevel) * MAX_SPEED_ADVANCE_PER_LEVEL

      // Si el avance calculado supera el umbral, lo limitamos
      if (calculatedAdvance > maxSpeedThreshold) {
          calculatedAdvance = maxSpeedThreshold
      }
      ```


    * `stamina`
      La stamina representa la resistencia del caballo y tiene el efecto de permitir el 100% del rendimiento hasta superar cierta cantidad de metros en la carrera. Luego de ese punto, el rendimiento del caballo disminuirá un 2% en cada tick, hasta alcanzar un mínimo del 80%, valor en el que permanecerá hasta el final de la carrera.

      Esto genera el efecto de que los caballos con bajo nivel en stamina serán más eficientes en carreras cortas, dado que el efecto del cansancio aparecerá cerca del final. En cambio, en carreras largas, su rendimiento será más deficiente porque el cansancio se manifestará pronto y el caballo deberá recorrer un largo tramo en estado de fatiga.

      un pseudo código sería:
      ```
      distancePerTick = length / TOTAL_RACE_ITERATIONS
      currentDistance = distancePerTick * tick

      staminaLevel = floor(log2(stamina))
      extraLenth = STAMINA_METERS_PER_LEVEL * staminaLevel

      threshold = MIN_DISTANCE_RESISTANCE + extraLenth
      finalPercent = 100
      if (threshold < currentDistance) {
          // Calculamos cuántos ticks han pasado desde que superamos el threshold
          afterThresholdTicks = floor((currentDistance - threshold) / distancePerTick)
          // Reducimos 2% por cada tick pasado
          finalPercent = 100 - (afterThresholdTicks * 2)
          // Nunca bajar de 80%
          if (finalPercent < 80) {
              finalPercent = 80
          }
      }
      ```

    * `acceleration`
      La aceleración representa qué tan rápido pasa el caballo de avanzar al 0% a alcanzar el 100%. Sin embargo, como el algoritmo está implementado en pasos discretos —concretamente, 20 ticks—, lo que se hace es calcular el valor que tendría normalmente si ya estuviera en su plenitud de velocidad y luego restarle un porcentaje que depende de dos factores.

      El primer factor es el número de tick: cuanto más bajo sea, mayor será el porcentaje que se resta, operando en un rango de 0 a MAX_ACCELERATION.

      El segundo factor es el nivel de la propiedad de aceleración, la cual empieza en cero y puede aumentar hasta un máximo de MAX_ACCELERATION. A mayor nivel en la propiedad de aceleración, más rápido alcanza el caballo su velocidad máxima. Es decir, el caballo debería tardar 8 tics en llegar a su plenitud de velocidad, menos el nivel de la propiedad de aceleración.

      Concretamete el calculo de cómo afecta la aceleración sería así:
      ```
      MAX_ACCELERATION = 8
      MIN_ACCELERATION = 2
      TOTAL_ACCELERATION = MAX_ACCELERATION + MIN_ACCELERATION
      // --
      accelerationLevel = log2(acceleration)
      speedUpRange = TOTAL_ACCELERATION - Min(MAX_ACCELERATION, accelerationLevel)
      hundredPercent = 100
      percentageGainPerTick = hundredPercent / speedUpRange
      finalPercentage = Min(hundredPercent, percentageGainPerTick * tick)
      ```
---

### 3. Gestión de puntos no asignados y cooldown tras carrera

> **Contexto:** Al terminar una carrera, el contrato de **Carrera** llamará a **CaballoNFT** para entregar los puntos ganados y bloquear temporalmente al caballo antes de su próxima inscripción.

```solidity
function setRacePrize(
    uint256 id,
    uint256 position,
    uint256 points
) external;
```

* **Flujo detallado:**

  1. **Verificación de llamada:** `require(msg.sender == address(Carrera));`
  2. **Acumulación de puntos:**

    ```solidity
    pointsUnassigned += points;
    ```
  3. **Cálculo del tiempo de descanso real:**

    * Dado que `raceCooldownStat` crece con puntos asignados, definimos una función inversa:

      ```
      restDelay = fInverse(raceCooldownStat)
      ```

      (a mayor stat, menor `restDelay`).
  4. **Actualización de `restFinish`:**

    ```solidity
    if (restFinish >= block.timestamp) {
        restFinish += restDelay;
    } else {
        restFinish = block.timestamp + restDelay;
    }
    ```

    De este modo, si el caballo ya estaba en espera, **acumula** tiempo adicional; si no, inicia un nuevo periodo desde “ahora”.

---

### 4. Asignación de puntos a stats y cooldown de alimentación

> **Contexto:** El jugador puede “alimentar” al caballo gastando HAY para distribuir sus `pointsUnassigned` en cualquiera de los stats, pero esto genera un bloqueo adicional de alimentación.

```solidity
function assignPoints(
    uint256  horseId,
    uint256  acceleration,
    uint256  stamina,
    uint256  minSpeed,
    uint256  maxSpeed,
    uint256  luck,
    uint256  curveBonus,
    uint256  straightBonus,
    uint256  raceCooldownStat,
    uint256  feedCooldownStat
) external;
```

* **Pasos:**

  1. **Aprobación de HAY:** El jugador hace `approve` por `totalPoints * pricePerPoint` al contrato CaballoNFT.
  2. **Transferencia de HAY:** `transferFrom(msg.sender, address(this), amount)`.
  3. **Distribución de puntos:**

    ```solidity
    pointsUnassigned -= totalPoints;
    pointsAssigned   += totalPoints;
    // Luego incrementa cada stat:
    stats.acceleration += acceleration;
    … // y así sucesivamente
    ```
  4. **Cálculo del tiempo de alimentación real:**

    ```solidity
    feedDelay = fInverse(feedCooldownStat);
    ```
  5. **Actualización de `feedFinish`:**

    ```solidity
    if (feedFinish >= block.timestamp) {
        feedFinish += feedDelay;
    } else {
        feedFinish = block.timestamp + feedDelay;
    }
    ```
  6. **Durante este periodo de alimentación**, el caballo:

    * **No** puede ser transferido.
    * **No** puede inscribirse (aunque podría terminar su descanso si ese cooldown ya venció).

---

### 5. Condiciones de libertad (inscripción vs. transferencia)

> **Contexto:** Debemos distinguir entre cuándo un caballo está listo para correr otra carrera y cuándo puede cambiar de dueño.

* **Libre para inscribirse en carrera** si y sólo si ambos cooldowns expiraron:

  ```solidity
  function canRegister(uint256 id) public view returns (bool) {
      return block.timestamp >= restFinish
          && block.timestamp >= feedFinish;
  }
  ```

* **Libre para transferirse** si y sólo si terminó su alimentación:

  ```solidity
  function canTransfer(uint256 id) public view returns (bool) {
      return block.timestamp >= feedFinish;
  }
  ```

---

### 6. Cálculo de nivel

> **Contexto:** El nivel refleja la progresión total de un caballo (puntos asignados + no asignados) y se computa como log₂ truncado. Se puede hacer de forma global (sobre los puntos totales) o para una propiedad concreta.

```solidity
function level(uint256 horseId) public view returns (uint256) {
    uint256 total = pointsAssigned[horseId] + pointsUnassigned[horseId];
    return floorLog2(total);
}

function levelProp(uint256 points) public view returns (uint256 result) {
    UD60x18 x = ud(points * 1e18);
    UD60x18 res = x.log2()
    result = res.intoUint256()
}
```

* **Ejemplo de `floorLog2`**:

  ```solidity
  function floorLog2(uint256 x) internal pure returns (uint256) {
      uint256 res;
      while (x > 1) {
          x >>= 1;
          res++;
      }
      return res;
  }
  ```

---

### 7. Seguridad y validaciones

> **Contexto:** Para garantizar integridad y evitar estados inconsistentes:

* **Modificadores**

  * `onlyRaceContract` en `setRacePrize`
  * `onlyWhenNotCoolingForRegistration` en inscripción de carrera que use `canRegister`
  * `onlyWhenNotCoolingForTransfer` en `transferFrom` personalizado que use `canTransfer`

* **ReentrancyGuard**

  * En `assignPoints` y en funciones de pago/eventos críticos.
