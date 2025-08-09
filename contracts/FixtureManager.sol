// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title FixtureManager
/// @notice Manages race fixtures and horse registrations.
/// @dev This is a simplified implementation based on the provided specification.
contract FixtureManager {
    string public version = "FixtureManager-v1.0.0";

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant MAX_FIXTURE_RACES = 8;
    uint256 public constant MAX_POINTS_DIFFERENCE_TOLERANCE = 20;
    uint256 public constant MAX_LEVELS_DIFFERENCE_TOLERANCE = 2;
    uint256 public constant FIXTURE_CONFIRM_TIME = 30 minutes;
    uint256 public constant FIXTURE_MIN_TIME_DISTANCE = 30 minutes;
    uint256 public constant FIXTURE_MAX_TIME_DISTANCE = 8 hours;
    uint256 public constant TIME_BETWEEN_RACES = 3 minutes;
    uint256 public constant MAX_RACE_PARTICIPANTS = 8;
    uint256 public constant MIN_RACE_PARTICIPANTS = 2;

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
        uint256[] positions;         // Resultado de la carrera
    }

    struct Fixture {
        uint256 startTime;           // Momento de comienzo de la primer carrera (también ID)
        uint256[] races;             // Carreras generadas
        uint256 currentRace;         // Índice de la carrera siguiente o en curso
        uint256 prevFixture;         // Referencia al Fixture anterior
    }

    struct Postponed {
        uint256 horseId;             // Id del caballo
        uint256 price;               // Premio en HAY por postergación
    }

    struct HorseInfo {
        uint256 level;               // Nivel del caballo
        uint256 points;              // Puntos del caballo
        bool veteran;                // True si es veterano, false si es novato
    }

    // ---------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------
    Postponed[] public postponed;           // Caballos postergados
    uint256[] public registered;            // Caballos inscriptos por orden

    mapping(uint256 => Fixture) public fixtures;  // Fixtures por startTime
    uint256 public currentFixture;                 // ID del fixture actual

    mapping(uint256 => HorseInfo) public horseInfo; // Datos de cada caballo

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event HorseRegistered(uint256 indexed horseId);
    event FixtureCreated(uint256 indexed startTime);
    event FixtureFinalized(uint256 indexed startTime);

    // ---------------------------------------------------------------------
    // Horse registration
    // ---------------------------------------------------------------------

    /// @notice Registers a horse for the next available race.
    /// @param horseId Id of the horse
    /// @param level Level of the horse
    /// @param points Total points of the horse
    /// @param veteran True if the horse is veteran, false if rookie
    function registerHorse(
        uint256 horseId,
        uint256 level,
        uint256 points,
        bool veteran
    ) external {
        require(horseId != 0, "Invalid horseId");
        horseInfo[horseId] = HorseInfo(level, points, veteran);
        registered.push(horseId);

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
        Fixture storage f = fixtures[currentFixture];

        if (f.startTime == 0) {
            // No fixture in progress, create a new one
            uint256 start = _calculateNextStartTime();
            currentFixture = start;
            f = fixtures[start];
            f.startTime = start;
            emit FixtureCreated(start);
        }

        if (block.timestamp >= f.startTime - FIXTURE_CONFIRM_TIME) {
            // Fixture is already confirmed; do not modify
            return;
        }

        uint256 idx = 0;
        while (f.races.length < MAX_FIXTURE_RACES && idx < registered.length) {
            uint256 remaining = registered.length - idx;
            if (remaining < MIN_RACE_PARTICIPANTS) {
                break;
            }

            // Determine number of participants for this race
            uint256 num = remaining > MAX_RACE_PARTICIPANTS ? MAX_RACE_PARTICIPANTS : remaining;
            uint256[] memory participants = new uint256[](num);
            uint256 maxLevel = 0;
            uint256 maxPoints = 0;
            for (uint256 i = 0; i < num; i++) {
                uint256 horseId = registered[idx + i];
                participants[i] = horseId;
                HorseInfo storage info = horseInfo[horseId];
                if (info.level > maxLevel) {
                    maxLevel = info.level;
                }
                if (info.points > maxPoints) {
                    maxPoints = info.points;
                }
            }

            // Build race
            Race memory race;
            race.horses = participants;
            race.level = maxLevel;
            race.length = _calculateRaceLength(maxLevel, num);
            race.startTime = f.startTime + (f.races.length * TIME_BETWEEN_RACES);
            race.iterations = race.length / 10; // dummy value

            f.races.push(f.races.length);
            // store race in mapping by pushing to an external array? For simplicity we ignore.
            // In a full implementation races would be stored separately

            idx += num;
        }

        // Remove processed horses
        _truncateRegistered(idx);
    }

    /// @dev Calculates the next start time for a fixture based on the number of
    ///      horses waiting. This is a naive approximation of the described
    ///      behaviour.
    function _calculateNextStartTime() internal view returns (uint256) {
        uint256 wait = FIXTURE_MAX_TIME_DISTANCE;
        uint256 total = registered.length + postponed.length;
        if (total > MAX_RACE_PARTICIPANTS) {
            wait = FIXTURE_MIN_TIME_DISTANCE;
        }
        return block.timestamp + wait;
    }

    /// @dev Calculates race length based on level and number of participants.
    function _calculateRaceLength(uint256 level, uint256 participants) internal pure returns (uint256) {
        uint256 base = 1000 + (level * 100);
        return base + (participants * 50);
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
    // Fixture finalization
    // ---------------------------------------------------------------------

    /// @notice Finalizes the current fixture and prepares the next one.
    function finalizeFixture() external {
        Fixture storage f = fixtures[currentFixture];
        require(f.startTime != 0, "No fixture in progress");
        require(block.timestamp >= f.startTime + (f.races.length * TIME_BETWEEN_RACES), "Fixture not finished");

        emit FixtureFinalized(f.startTime);

        // Prepare next fixture
        currentFixture = 0;
        _tryGenerateFixture();
    }
}

