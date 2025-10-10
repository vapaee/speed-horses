// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UFix6, SpeedH_UFix6Lib } from "./SpeedH_UFix6Lib.sol";

interface IHorses {
    function getLevel(uint256 horseId) external view returns (UFix6 level);
    function getTotalPoints(uint256 horseId) external view returns (uint256 points);
}

/// @title SpeedH_FixtureManager
/// @notice Manages race fixtures and horse registrations.
/// @dev This is a simplified implementation based on the provided specification.
/**
 * Título: SpeedH_FixtureManager
 * Brief: Orquestador de las carreras que se encarga de recibir inscripciones, organizar caballos por puntaje y armar las tandas de competencias respetando capacidades, tiempos y compensaciones. Administra el ciclo de vida de cada fixture desde su creación hasta su confirmación, calculando longitudes de pista y premios de consolación mientras coordina con el contrato de estadísticas y el token HAY.
 * API: los jugadores interactúan mediante `registerHorse`, que dispara internamente `_tryGenerateFixture` para avanzar en el proceso de armado; el contrato expone utilidades privadas (`_calculateNextStartTime`, `_calculateRaceLength`, `_min`) que determinan horarios y distancias de las carreras, y mantiene getters como `isRegistered` para consultas externas. Las funciones administrativas (`setHorseStats`, `setHayToken`) conectan las dependencias necesarias, completando el flujo de preparación de fixtures antes de las simulaciones de carrera.
 */
contract SpeedH_FixtureManager {
    string public version = "SpeedH_FixtureManager-v1.0.0";

    // ---------------------------------------------------------------------
    // Contract References
    // ---------------------------------------------------------------------
    address public admin;
    address public horseStats;
    address public hayToken;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_FIXTURE_RACES = 8;
    uint256 public constant MIN_FIXTURE_RACES = 2;
    uint256 public constant FIXTURE_CONFIRM_TIME = 30 minutes;
    uint256 public constant FIXTURE_MIN_TIME_DISTANCE = 30 minutes;
    uint256 public constant FIXTURE_MAX_TIME_DISTANCE = 8 hours;
    uint256 public constant TIME_BETWEEN_RACES = 3 minutes;
    uint256 public constant TOTAL_TRACK_LENGTH = 1200;
    uint256 public constant MAX_HORSES_PER_RACE = 6;
    uint256 public constant MIN_HORSES_PER_RACE = 3;
    uint256 public constant MAX_HORSE_LEVEL_TRACK_MODIFIER = 10;
    uint256 public constant MAX_FIXTURE_PARTICIPANTS = MAX_FIXTURE_RACES * MAX_HORSES_PER_RACE;
    uint256 public constant MIN_FIXTURE_PARTICIPANTS = MIN_FIXTURE_RACES * MIN_HORSES_PER_RACE;
    uint256 public constant RACE_HORSE_INSCRIPTION_COST_PER_LEVEL = 100 ether;
    uint256 public constant CONSOLATION_PRIZE_PER_LEVEL = 50 ether;
    uint256 public constant MAX_POINTS_DIFFERENCE_TOLERANCE = 100;
    uint256 private constant UFIX6_SCALE = 1e6;

    // ---------------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------------
    struct Race {
        uint256[] horses;            // Id de los caballos que corren la carrera
        uint256 length;              // Longitud de la carrera en metros
        uint256 level;               // Nivel de la carrera (igual al nivel del mejor caballo)
        uint256 startTime;           // Momento de comienzo de la carrera
        uint256 iterations;          // Cantidad de iteraciones que llevará completar la carrera
        bytes32[] seeds;             // Semillas correspondientes a tiempo pasado
        uint256[] positions;         // Resultado de la carrera (ordenado por posición)
        bool finished;               // Si la carrera ya finalizó
    }

    struct Fixture {
        uint256 startTime;           // Momento de comienzo de la primer carrera (también ID)
        uint256 horsesCount;         // Cantidad de caballos inscriptos
        Race[] races;                // Carreras generadas
        uint256 currentRace;         // Índice de la carrera siguiente o en curso
        uint256 prevFixture;         // Referencia al Fixture anterior
        bool confirmed;              // Si el fixture ya fue confirmado (no sufre cambios)
        bool finished;               // Si el fixture ya finalizó
    }

    struct SignedHorse {
        uint256 horseId;             // Id del caballo
        uint256 points;              // Puntos del caballo
        uint256 prize;               // Premio en HAY por postergación
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    SignedHorse[] public horseList;                // Caballos inscriptos (ordenados por puntaje)
    SignedHorse[] public pending;                  // Caballos aplazados (ordenados por puntaje)
    mapping(uint256 => bool) public registered;    // Caballos inscriptos por ID
    mapping(uint256 => Fixture) public fixtures;   // Fixtures por startTime
    uint256 public currentFixture;                 // ID del fixture actual


    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event HorseRegistered(uint256 indexed horseId);
    event FixtureCreated(uint256 indexed startTime);
    event FixtureFinalized(uint256 indexed startTime);

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function setHorseStats(address _stats) external onlyAdmin {
        horseStats = _stats;
    }

    function setHayToken(address _token) external onlyAdmin {
        hayToken = _token;
    }

    // ---------------------------------------------------------------------
    // Horse registration
    // ---------------------------------------------------------------------

    /// @notice Registers a horse for the next available fixture.
    /// @param horseId Id of the horse
    function registerHorse(uint256 horseId) external {
        // Cobramos el costo de inscripción basado en el nivel del caballo
        UFix6 level = IHorses(horseStats).getLevel(horseId);
        uint256 levelScaled = SpeedH_UFix6Lib.raw(level);
        uint256 cost = (levelScaled * RACE_HORSE_INSCRIPTION_COST_PER_LEVEL) / UFIX6_SCALE;
        IERC20(hayToken).transferFrom(msg.sender, address(this), cost);

        // Verificamos si el caballo ya está registrado
        require(!registered[horseId], "Horse already registered");

        // Incluimos el caballo en la lista de inscriptos
        uint256 points = IHorses(horseStats).getTotalPoints(horseId);
        horseList.push(SignedHorse({horseId: horseId, points: points, prize: 0}));

        // Ordenamos el array de inscriptos por puntaje (buble sort simplificado)
        // Este algoritmo es O(n^2) pero dado que la lista ya está ordenada es O(n)
        // El peor caballo se encuentra al principio de la lista
        uint256 i = horseList.length - 1;
        while (i > 0 && horseList[i].points < horseList[i - 1].points) {
            SignedHorse memory tmp = horseList[i - 1];
            horseList[i - 1] = horseList[i];
            horseList[i] = tmp;
            i--;
        }

        registered[horseId] = true;
        emit HorseRegistered(horseId);

        _tryGenerateFixture();
    }

    // ---------------------------------------------------------------------
    // Fixture generation logic (simplified)
    // ---------------------------------------------------------------------

    /// @dev Attempts to generate races within the current fixture using
    ///      registered and postponed horses. This implementation groups horses
    ///      in the order they arrive, respecting basic constraints but does
    ///      not fully implement the algorithm described in the specification.
    function _tryGenerateFixture() internal {

        // Caso inicial (primer fixture)
        if (currentFixture == 0) {
            // No fixture in progress, create a new one
            uint256 start = _calculateNextStartTime();
            Fixture storage new_f = fixtures[start];
            new_f.startTime = start;
            new_f.currentRace = 0;
            new_f.prevFixture = 0;
            new_f.horsesCount = 0;
            currentFixture = start;
            emit FixtureCreated(start);
        }

        Fixture storage f = fixtures[currentFixture];

        // Check if fixture is already confirmed
        if (block.timestamp >= f.startTime - FIXTURE_CONFIRM_TIME) {
            if (!f.confirmed) {
                // Fixture is not confirmed yet, but time has passed
                f.confirmed = true;
                emit FixtureFinalized(f.startTime);
            }
            // Fixture is confirmed, no more modifications allowed
            return;
        }

        // Check if fixture is full
        if (f.horsesCount >= MAX_FIXTURE_PARTICIPANTS) {
            // Fixture is full; do not modify
            return;
        }

        // TODO: Crear las carreras dentro del fixture:
        // -- Inicialización --
        // Creamos una lista temporal de carreras

        // variable horsesCount = 0 será el contador de caballos que efectivamente correrán
        // variable currentRace = 0 será el índice de la carrera actual dentro de esa lista temporal
        // variable worstHorseOnRace = horseList[0];
        // agregamos el worstHorseOnRace a la carrera actual
        Race[] memory tempRaces;
        uint256 raceIndex = 0;
        SignedHorse memory worstHorseOnRace = horseList[0];
        // -- Procedimiento --
        // Iteramos sobre todos los caballos registrados (a partir del segundo) y en cada iteración:
        // - Si la carrera actual ya tiene exactamente MAX_HORSES_PER_RACE entonces:
        //   - currentRace apunta a la siguiente carrera
        //   - agregamos el caballo actual a la nueva carrera
        //   - worstHorseOnRace pasa a ser el caballo actual
        // - Si el caballo actual difiere del worstHorseOnRace en menos (o igual) de MAX_POINTS_DIFFERENCE_TOLERANCE entonces:
        //   - agregamos el caballo a la carrera actual
        // - Si el caballo actual difiere del worstHorseOnRace en más de MAX_POINTS_DIFFERENCE_TOLERANCE entonces:
        //   - currentRace apunta a la siguiente carrera
        //   - agregamos el caballo actual a la nueva carrera
        //   - worstHorseOnRace pasa a ser el caballo actual
        for (uint256 i = 1; i < horseList.length; i++) {
            SignedHorse memory currentHorse = horseList[i];
            uint256 horseIndex = 0;
            if (tempRaces[raceIndex].horses.length >= MAX_HORSES_PER_RACE) {
                // Carrera llena, pasamos a la siguiente
                raceIndex++;
                tempRaces[raceIndex].horses[0] = currentHorse.horseId;
                horseIndex = 1;
                worstHorseOnRace = currentHorse;
                // TODO: remplazar la condición de diferir por una sonstante a diferir por un porcentaje
            } else if (currentHorse.points - worstHorseOnRace.points <= MAX_POINTS_DIFFERENCE_TOLERANCE) {
                // Caballo dentro del rango de tolerancia, lo agregamos a la carrera actual
                tempRaces[raceIndex].horses[horseIndex] = currentHorse.horseId;
                horseIndex++;
            } else {
                // Caballo fuera del rango de tolerancia, iniciamos una nueva carrera
                raceIndex++;
                tempRaces[raceIndex].horses[0] = currentHorse.horseId;
                horseIndex = 1;
                worstHorseOnRace = currentHorse;
            }
        }
        // -- Limpieza --
        // - creamos una lista temporal de caballos que no correrán en este fixture
        // - Iteramos sobre las carreras para verificar si tienen suficientes caballos (race.horses.length >= MIN_HORSES_PER_RACE)
        //  - Si tienen suficientes caballos y todavía no alcanzamos el máximo de carreras (fixture.races.length >= MAX_FIXTURE_RACES),
        //    - entonces agregamos la carrera al fixture
        //    - incrementamos horsesCount con la cantidad de caballos de la carrera
        //  - Si no tienen suficientes caballos o el fixture ya está lleno
        //    - agregamos los caballos a la lista temporal de caballos que no correrán
        //    - le asignamos un premio consuelo a cada caballo según su level
        //    - descartamos la carrera
        //  - Finalmente, actualizamos el fixture actual con las carreras generadas y el contador horsesCount
        //  - Si horsesCount >= MAX_FIXTURE_PARTICIPANTS, entonces confirmamos el fixture y emitimos el evento FixtureConfirmed
        //  - sustituimos la lista de pending por la lista de caballos que no correrán
        SignedHorse[] memory notRacing;
        uint256 notRacingIndex = 0;
        uint256 fixtureRaceIndex = 0;
        // Iteramos sobre las carreras temporales para agregarlas al fixture
        for (uint256 j = 0; j <= raceIndex; j++) {
            // Verificamos si la situación de la carrera es válida
            if (tempRaces[j].horses.length >= MIN_HORSES_PER_RACE && f.races.length < MAX_FIXTURE_RACES) {
                // Carrera válida, la agregamos al fixture
                uint256 level = 0;
                for (uint256 k = 0; k < tempRaces[j].horses.length; k++) {
                    uint256 horseId = tempRaces[j].horses[k];
                    uint256 horseLevel = SpeedH_UFix6Lib.toUint(IHorses(horseStats).getLevel(horseId));
                    if (horseLevel > level) {
                        level = horseLevel;
                    }
                }
                uint256 length = _calculateRaceLength(level, tempRaces[j].horses.length);
                uint256 startTime = f.startTime + f.currentRace * TIME_BETWEEN_RACES;
                Race storage currentRace = f.races[fixtureRaceIndex];
                currentRace.horses = tempRaces[j].horses;
                currentRace.length = length;
                currentRace.level = level;
                currentRace.startTime = startTime;
                currentRace.iterations = 0; // TODO: resolver cómo calcular iteraciones
                currentRace.finished = false;
                fixtureRaceIndex++;
                f.horsesCount += tempRaces[j].horses.length;
            } else {
                // Carrera inválida, los caballos no correrán
                for (uint256 l = 0; l < tempRaces[j].horses.length; l++) {
                    uint256 horseId = tempRaces[j].horses[l];
                    uint256 horsePoints = IHorses(horseStats).getTotalPoints(horseId);
                    uint256 level = SpeedH_UFix6Lib.toUint(IHorses(horseStats).getLevel(horseId));
                    uint256 prize = level * CONSOLATION_PRIZE_PER_LEVEL;
                    notRacing[notRacingIndex] = SignedHorse({
                        horseId: horseId,
                        points: horsePoints,
                        prize: prize
                    });
                    notRacingIndex++;
                }
            }
        }
        if (f.horsesCount >= MAX_FIXTURE_PARTICIPANTS) {
            // Fixture lleno, confirmamos
            f.confirmed = true;
            emit FixtureFinalized(f.startTime);
        }
        // Reemplazamos la lista de pending con los caballos que no correrán
        delete pending;
        for (uint256 m = 0; m < notRacingIndex; m++) {
            pending.push(notRacing[m]);
        }
    }

    /// @dev Calculates the next start time for a fixture based on the number of
    ///      horses waiting. This is a naive approximation of the described
    ///      behavior.
    function _calculateNextStartTime() internal view returns (uint256) {
        uint256 wait = 0;
        // TODO: verificar cual es la lista de caballos que esperan
        uint256 totalHorsesWaiting = horseList.length + pending.length;
        if (totalHorsesWaiting > MAX_FIXTURE_PARTICIPANTS) {
            wait = FIXTURE_MIN_TIME_DISTANCE;
        } else if (totalHorsesWaiting < MIN_FIXTURE_PARTICIPANTS) {
            wait = FIXTURE_MAX_TIME_DISTANCE;
        } else {
            // Minimun time to wait
            uint256 minWait = FIXTURE_MIN_TIME_DISTANCE;
            // Remaining waiting time that depends on waiting horses
            uint256 diffWait = FIXTURE_MAX_TIME_DISTANCE - FIXTURE_MIN_TIME_DISTANCE;
            // Maximum waiting horses that can race in next fixture
            uint256 maxDifference = MAX_FIXTURE_PARTICIPANTS - MIN_FIXTURE_PARTICIPANTS;
            // Actual waiting horses that decides how much time will be added
            uint256 waitingHorses = totalHorsesWaiting - MIN_FIXTURE_PARTICIPANTS;
            uint256 proportionalWaiting = (maxDifference - waitingHorses) / maxDifference;
            wait = minWait + diffWait * proportionalWaiting;
        }
        return block.timestamp + wait;
    }

    /// @dev Calculates race length based on level and number of participants.
    function _calculateRaceLength(uint256 level, uint256 participants) internal pure returns (uint256) {
        uint256 part1 = TOTAL_TRACK_LENGTH / 3;
        uint256 part2 = (TOTAL_TRACK_LENGTH / 3) * (participants - MIN_HORSES_PER_RACE) / (MAX_HORSES_PER_RACE - MIN_HORSES_PER_RACE);
        uint256 part3 = (TOTAL_TRACK_LENGTH / 3) * (_min(MAX_HORSE_LEVEL_TRACK_MODIFIER, level) ) / MAX_HORSE_LEVEL_TRACK_MODIFIER;
        return part1 + part2 + part3;
    }

    /// @dev Calculates and returns the minimun between two values;
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b) return a;
        return b;
    }

    /// @dev Removes the first `count` elements from the registered array.
    // TODO: verificar si es útil esta función
    /*function _truncateRegistered(uint256 count) internal {
        if (count == 0) return;
        require(count <= registered.length, "Too many to remove");

        for (uint256 i = count; i < registered.length; i++) {
            registered[i - count] = registered[i];
        }
        for (uint256 j = 0; j < count; j++) {
            registered.pop();
        }
    }*/

    // ---------------------------------------------------------------------
    // Getters
    // ---------------------------------------------------------------------

    function isRegistered(uint256 horseId) external view returns (bool) {
        return registered[horseId];
    }

}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
