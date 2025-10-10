// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UFix6, SpeedH_UFix6Lib } from "./SpeedH_UFix6Lib.sol";

interface IHorses {
    function getLevel(uint256 horseId) external view returns (UFix6 level);
    function getTotalPoints(uint256 horseId) external view returns (uint256 points);
    function getEquippedHorseshoes(uint256 horseId) external view returns (uint256[] memory);
    function isHorseshoeUseful(uint256 horseshoeId) external view returns (bool);
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
    using SafeERC20 for IERC20;

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
    uint256 public constant REQUIRED_HORSESHOES = 4;

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
        require(_stats != address(0), "SpeedH_FixtureManager: invalid stats");
        horseStats = _stats;
    }

    function setHayToken(address _token) external onlyAdmin {
        require(_token != address(0), "SpeedH_FixtureManager: invalid HAY token");
        hayToken = _token;
    }

    // ---------------------------------------------------------------------
    // Horse registration
    // ---------------------------------------------------------------------

    /// @notice Registers a horse for the next available fixture.
    /// @param horseId Id of the horse
    function registerHorse(uint256 horseId) external {
        require(horseStats != address(0), "SpeedH_FixtureManager: horse stats not set");
        require(hayToken != address(0), "SpeedH_FixtureManager: HAY token not set");

        uint256[] memory equipped = IHorses(horseStats).getEquippedHorseshoes(horseId);
        require(equipped.length == REQUIRED_HORSESHOES, "SpeedH_FixtureManager: incomplete horseshoes");
        for (uint256 i = 0; i < equipped.length; i++) {
            require(
                IHorses(horseStats).isHorseshoeUseful(equipped[i]),
                "SpeedH_FixtureManager: worn horseshoe"
            );
        }

        // Cobramos el costo de inscripción basado en el nivel del caballo
        UFix6 level = IHorses(horseStats).getLevel(horseId);
        uint256 levelScaled = SpeedH_UFix6Lib.raw(level);
        uint256 cost = (levelScaled * RACE_HORSE_INSCRIPTION_COST_PER_LEVEL) / UFIX6_SCALE;
        IERC20(hayToken).safeTransferFrom(msg.sender, address(this), cost);

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
        require(horseStats != address(0), "SpeedH_FixtureManager: horse stats not set");

        // Si no existe fixture activo creamos uno nuevo para iniciar la planificación
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

        // Cancelamos cualquier edición cuando el fixture ya entró en ventana de confirmación
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

        // No avanzamos si ya alcanzamos el cupo máximo para el fixture vigente
        // Check if fixture is full
        if (f.horsesCount >= MAX_FIXTURE_PARTICIPANTS) {
            // Fixture is full; do not modify
            return;
        }

        // Si no hay caballos en espera terminamos inmediatamente
        uint256 totalQueue = horseList.length + pending.length;
        if (totalQueue == 0) {
            return;
        }

        // Unificamos pendientes y recientes en una sola cola ordenada por puntos
        SignedHorse[] memory queue = new SignedHorse[](totalQueue);
        uint256 queueIndex;
        for (uint256 i = 0; i < pending.length; i++) {
            queue[queueIndex] = pending[i];
            queueIndex++;
        }
        for (uint256 i = 0; i < horseList.length; i++) {
            queue[queueIndex] = horseList[i];
            queueIndex++;
        }

        delete pending;
        delete horseList;

        // Preparamos contenedores auxiliares para guardar lo que no entra en el fixture actual
        SignedHorse[] memory carryOver = new SignedHorse[](totalQueue);
        uint256 carryOverCount;
        uint256 processed;

        // Recorremos la cola formando carreras siempre que haya cupo y fixtures disponibles
        while (
            processed < totalQueue &&
            f.races.length < MAX_FIXTURE_RACES &&
            f.horsesCount < MAX_FIXTURE_PARTICIPANTS
        ) {
            // Seleccionamos un lote de caballos candidatos manteniendo coherencia de puntajes
            SignedHorse[] memory raceParticipants = new SignedHorse[](MAX_HORSES_PER_RACE);
            uint256 participantsCount;
            SignedHorse memory baseHorse = queue[processed];

            while (processed < totalQueue && participantsCount < MAX_HORSES_PER_RACE) {
                SignedHorse memory currentHorse = queue[processed];
                if (
                    participantsCount == 0 ||
                    currentHorse.points - baseHorse.points <= MAX_POINTS_DIFFERENCE_TOLERANCE
                ) {
                    raceParticipants[participantsCount] = currentHorse;
                    participantsCount++;
                    processed++;
                } else {
                    break;
                }
            }

            // Si no alcanzamos el mínimo, devolvemos esos caballos con su premio de consolación
            if (participantsCount < MIN_HORSES_PER_RACE) {
                for (uint256 i = 0; i < participantsCount; i++) {
                    SignedHorse memory entry = raceParticipants[i];
                    uint256 horseLevel = SpeedH_UFix6Lib.toUint(IHorses(horseStats).getLevel(entry.horseId));
                    entry.prize = horseLevel * CONSOLATION_PRIZE_PER_LEVEL;
                    carryOver[carryOverCount] = entry;
                    carryOverCount++;
                }
                continue;
            }

            // Si el fixture casi no tiene espacios disponibles, devolvemos todos los candidatos
            uint256 availableSlots = MAX_FIXTURE_PARTICIPANTS - f.horsesCount;
            if (availableSlots < MIN_HORSES_PER_RACE) {
                for (uint256 i = 0; i < participantsCount; i++) {
                    SignedHorse memory entry = raceParticipants[i];
                    uint256 horseLevel = SpeedH_UFix6Lib.toUint(IHorses(horseStats).getLevel(entry.horseId));
                    entry.prize = horseLevel * CONSOLATION_PRIZE_PER_LEVEL;
                    carryOver[carryOverCount] = entry;
                    carryOverCount++;
                }
                break;
            }

            // Recortamos la lista si hay más candidatos que lugares restantes en el fixture
            if (participantsCount > availableSlots) {
                participantsCount = availableSlots;
            }

            // Revalidamos el mínimo tras el recorte y pagamos consolación si corresponde
            if (participantsCount < MIN_HORSES_PER_RACE) {
                for (uint256 i = 0; i < participantsCount; i++) {
                    SignedHorse memory entry = raceParticipants[i];
                    uint256 horseLevel = SpeedH_UFix6Lib.toUint(IHorses(horseStats).getLevel(entry.horseId));
                    entry.prize = horseLevel * CONSOLATION_PRIZE_PER_LEVEL;
                    carryOver[carryOverCount] = entry;
                    carryOverCount++;
                }
                break;
            }

            // Instanciamos una nueva carrera y almacenamos los caballos asignados
            Race storage race = f.races.push();
            race.horses = new uint256[](participantsCount);
            uint256 maxLevel;

            for (uint256 i = 0; i < participantsCount; i++) {
                SignedHorse memory entry = raceParticipants[i];
                race.horses[i] = entry.horseId;
                uint256 horseLevel = SpeedH_UFix6Lib.toUint(IHorses(horseStats).getLevel(entry.horseId));
                if (horseLevel > maxLevel) {
                    maxLevel = horseLevel;
                }
            }

            // Calculamos parámetros de la carrera según nivel y posición en el fixture
            race.length = _calculateRaceLength(maxLevel, participantsCount);
            race.level = maxLevel;
            uint256 raceIdx = f.races.length - 1;
            race.startTime = f.startTime + raceIdx * TIME_BETWEEN_RACES;
            race.iterations = 0;
            race.finished = false;

            f.horsesCount += participantsCount;
        }

        // Todo lo que quedó sin procesar recibe premio y pasa al listado de pendientes
        while (processed < totalQueue) {
            SignedHorse memory entry = queue[processed];
            uint256 horseLevel = SpeedH_UFix6Lib.toUint(IHorses(horseStats).getLevel(entry.horseId));
            entry.prize = horseLevel * CONSOLATION_PRIZE_PER_LEVEL;
            carryOver[carryOverCount] = entry;
            carryOverCount++;
            processed++;
        }

        // Persistimos los caballos pendientes para el siguiente intento de generación
        for (uint256 i = 0; i < carryOverCount; i++) {
            pending.push(carryOver[i]);
        }

        // Confirmamos automáticamente el fixture si se completó el cupo total
        if (f.horsesCount >= MAX_FIXTURE_PARTICIPANTS) {
            f.confirmed = true;
            emit FixtureFinalized(f.startTime);
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
