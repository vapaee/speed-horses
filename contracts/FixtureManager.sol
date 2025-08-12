// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHorses {
    function getLevel(uint256 horseId) external view returns (uint256 level);
    function getTotalPoints(uint256 horseId) external view returns (uint256 points);
}

/// @title FixtureManager
/// @notice Manages race fixtures and horse registrations.
/// @dev This is a simplified implementation based on the provided specification.
contract FixtureManager {
    string public version = "FixtureManager-v1.0.0";

    // ---------------------------------------------------------------------
    // Contract References
    // ---------------------------------------------------------------------
    address public admin;
    address public horseStats;

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
    constructor() {
        admin = msg.sender;
    }

    function setHorseStats(address _stats) external onlyAdmin {
        horseStats = _stats;
    }

    // ---------------------------------------------------------------------
    // Horse registration
    // ---------------------------------------------------------------------

    /// @notice Registers a horse for the next available fixture.
    /// @param horseId Id of the horse
    function registerHorse(uint256 horseId) external {
        // Cobramos el costo de inscripción basado en el nivel del caballo
        uint256 level = IHorses(horseStats).getLevel(horseId);
        uint256 cost = level * RACE_HORSE_INSCRIPTION_COST_PER_LEVEL;
        hayToken.transferFrom(msg.sender, address(this), cost);

        // Verificamos si el caballo ya está registrado
        require(!registered[horseId], "Horse already registered");

        // Incluimos el caballo en la lista de inscriptos
        uint256 points = IHorses(horseStats).getTotalPoints(horseId);
        horseList.push(Registred({horseId: horseId, points: points, prize: 0}));

        // Ordenamos el array de inscriptos por puntaje (buble sort simplificado)
        // Este algoritmo es O(n^2) pero dado que la lista ya está ordenada es O(n)
        // El peor caballo se encuentra al principio de la lista
        uint256 i = horseList.length - 1;
        while (i > 0 && horseList[i].points < horseList[i - 1].points) {
            Registred memory tmp = horseList[i - 1];
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
            // Fixture is already confirmed; do not modify
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
        uint256 horsesCount = 0;
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
            if (tempRaces[raceIndex].horses.length >= MAX_HORSES_PER_RACE) {
                raceIndex++;
                tempRaces[raceIndex].horses.push(currentHorse.horseId);
                worstHorseOnRace = currentHorse;
            } else if (currentHorse.points - worstHorseOnRace.points <= MAX_POINTS_DIFFERENCE_TOLERANCE) {
                tempRaces[raceIndex].horses.push(currentHorse.horseId);
            } else {
                raceIndex++;
                tempRaces[raceIndex].horses.push(currentHorse.horseId);
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
        Fixture storage f = fixtures[currentFixture];
        for (uint256 j = 0; j <= raceIndex; j++) {
            if (tempRaces[j].horses.length >= MIN_HORSES_PER_RACE && f.races.length < MAX_FIXTURE_RACES) {
                

    }

    /// @dev Calculates the next start time for a fixture based on the number of
    ///      horses waiting. This is a naive approximation of the described
    ///      behavior.
    function _calculateNextStartTime() internal view returns (uint256) {
        uint256 wait = 0;
        uint256 totalHorsesWaiting = registered.length + postponed.length;
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
        uint256 part3 = (TOTAL_TRACK_LENGTH / 3) * (min(MAX_HORSE_LEVEL_TRACK_MODIFIER, level) ) / MAX_HORSE_LEVEL_TRACK_MODIFIER;
        return part1 + part2 + part3;
    }

    /// @dev Removes the first `count` elements from the registered array.
    function _truncateRegistered(uint256 count) internal {
        if (count == 0) return;
        require(count <= registered.length, "Too many to remove");

        for (uint256 i = count; i < registered.length; i++) {
            registered[i - count] = registered[i];
        }
        for (uint256 j = 0; j < count; j++) {
            registered.pop();
        }
    }

    // ---------------------------------------------------------------------
    // Getters
    // ---------------------------------------------------------------------

    function isRegistered(uint256 horseId) external view returns (bool) {
        return registered[horseId];
    }

}

