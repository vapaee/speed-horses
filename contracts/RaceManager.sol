// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './Constants.sol';

interface IHorses {
    function level(uint256 horseId) external view returns (uint256);
    function pointsAssigned(uint256 horseId) external view returns (uint256);
    function pointsUnassigned(uint256 horseId) external view returns (uint256);
    function ownerOf(uint256 horseId) external view returns (address);
    function hayToken() external view returns (IERC20);
}

contract RaceManager {
    // --------------------------------------------------
    // Estructuras de datos y almacenamiento
    // --------------------------------------------------

    struct Race {
        // Datos iniciales de la carrera
        uint256[] horses;       // caballos participantes
        uint256 length;         // longitud total en metros
        uint256 level;          // nivel de la carrera
        uint256 startTime;      // inicio programado
        uint256 iterations;     // iteraciones totales
        // Evolución en el tiempo
        bytes32[] seeds;        // semillas registradas
        // Resultado final
        uint256[] positions;    // posiciones finales
    }

    struct Fixture {
        uint256 startTime;      // inicio de la primer carrera
        Race[] races;           // carreras del fixture
        uint256 currentRace;    // índice de la carrera en ejecución
    }

    struct Postponed {
        uint256 horseId;        // caballo pendiente
        uint256 price;          // premio consuelo
    }

    struct SeedEntry {
        bytes32 seed;
        uint256 timestamp;
    }

    IHorses public immutable horses;
    IERC20  public immutable hayToken;

    // Listas de espera
    Postponed[] public postponed;
    uint256[]  public registered;

    // Fixtures generados por id
    mapping(uint256 => Fixture) public fixtures;
    uint256 public current; // id del fixture actual

    // Cola de semillas pseudoaleatorias
    SeedEntry[] public seedQueue;

    // --------------------------------------------------
    // Constructor
    // --------------------------------------------------

    constructor(IHorses _horses) {
        horses = _horses;
        hayToken = _horses.hayToken();
    }

    // --------------------------------------------------
    // Lógica de Fixtures
    // --------------------------------------------------

    /// @notice Crea el siguiente fixture basándose en la cantidad de caballos en espera
    function createNextFixture() external {
        uint256 nextStart = block.timestamp + computeInterval();
        current = nextStart;
        fixtures[nextStart].startTime = nextStart;
        regenerateFixture(nextStart);
    }

    /// @notice Regenera el fixture indicado agrupando los caballos en carreras
    function regenerateFixture(uint256 fixtureId) public {
        Fixture storage f = fixtures[fixtureId];
        delete f.races;
        f.currentRace = 0;

        uint256 count = postponed.length + registered.length;
        uint256 idxPost = 0;
        uint256 idxReg  = 0;
        while (count > 0 && totalHorses(f) < MAX_FIXTURE_HORSES) {
            uint256 horseId;
            if (idxPost < postponed.length) {
                horseId = postponed[idxPost].horseId;
                idxPost++;
            } else {
                horseId = registered[idxReg];
                idxReg++;
            }
            _placeHorse(f, horseId);
            count--;
        }
    }

    /// @notice Inscribe un caballo para la próxima carrera
    function registerHorse(uint256 horseId) external {
        uint256 level_ = horses.level(horseId);
        uint256 cost = level_ * RACE_HORSE_INSCRIPTION_COST_PER_LEVEL;
        hayToken.transferFrom(msg.sender, address(this), cost);
        registered.push(horseId);
        if (totalHorses(fixtures[current]) < MAX_FIXTURE_HORSES && block.timestamp < fixtures[current].startTime - FIXTURE_CONFIRM_TIME) {
            regenerateFixture(current);
        }
    }

    // --------------------------------------------------
    // Simulación de carreras
    // --------------------------------------------------

    function simulateRace(uint256 fixtureId, uint256 raceIndex) external view returns (uint256[] memory) {
        return simulateRaceFrom(fixtureId, raceIndex, 0);
    }

    function simulateRaceFrom(uint256 fixtureId, uint256 raceIndex, uint256 startIteration) public view returns (uint256[] memory) {
        Fixture storage f = fixtures[fixtureId];
        Race storage r = f.races[raceIndex];
        uint256[] memory pos = new uint256[](r.horses.length);
        // Simple simulación: ordenar por id usando semilla
        for (uint256 i = 0; i < r.horses.length; i++) {
            pos[i] = r.horses[i];
        }
        return pos;
    }

    function runRace(uint256 fixtureId, uint256 raceIndex) external {
        Fixture storage f = fixtures[fixtureId];
        Race storage r = f.races[raceIndex];
        require(block.timestamp >= r.startTime, 'aun no inicia');
        if (r.positions.length == 0) {
            r.positions = simulateRace(fixtureId, raceIndex);
        }
    }

    // --------------------------------------------------
    // Manejo de semillas
    // --------------------------------------------------

    function addSeed(bytes32 seedUsed, bytes32 random) external {
        require(seedQueue.length > 0, 'cola vacia');
        SeedEntry storage last = seedQueue[seedQueue.length - 1];
        require(block.timestamp - last.timestamp <= SEED_TIME_THRESHOLD, 'semilla vieja');
        require(seedUsed == last.seed, 'semilla invalida');
        bytes32 hashed = keccak256(abi.encodePacked(seedUsed, random));
        require(uint256(hashed) < SEED_HASH_THRESHOLD, 'hash grande');

        bytes32 newSeed = hashed;
        if (seedQueue.length >= SEED_CHAIN_LENGTH) {
            uint256 start = seedQueue.length - SEED_CHAIN_LENGTH;
            for (uint256 i = start; i < seedQueue.length; i++) {
                newSeed = keccak256(abi.encodePacked(newSeed, seedQueue[i].seed));
            }
        }
        if (seedQueue.length >= MAX_SEED_QUEUE_LENGTH) {
            for (uint256 j = 1; j < seedQueue.length; j++) {
                seedQueue[j-1] = seedQueue[j];
            }
            seedQueue[seedQueue.length - 1] = SeedEntry(newSeed, block.timestamp);
        } else {
            seedQueue.push(SeedEntry(newSeed, block.timestamp));
        }
    }

    // --------------------------------------------------
    // Funciones internas auxiliares
    // --------------------------------------------------

    function computeInterval() internal view returns (uint256) {
        uint256 len = registered.length + postponed.length;
        uint256 range = FIXTURE_MAX_TIME_DISTANCE - FIXTURE_MIN_TIME_DISTANCE;
        if (len >= MAX_FIXTURE_HORSES) return FIXTURE_MIN_TIME_DISTANCE;
        uint256 pct = (len * 1e18) / MAX_FIXTURE_HORSES;
        return FIXTURE_MAX_TIME_DISTANCE - (range * pct / 1e18);
    }

    function totalHorses(Fixture storage f) internal view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < f.races.length; i++) {
            total += f.races[i].horses.length;
        }
        return total;
    }

    function _placeHorse(Fixture storage f, uint256 horseId) internal {
        uint256 lv = horses.level(horseId);
        for (uint256 i = 0; i < f.races.length; i++) {
            Race storage r = f.races[i];
            if (r.horses.length < MAX_HORSES_PER_RACE && _compatible(r.level, lv)) {
                r.horses.push(horseId);
                if (lv > r.level) r.level = lv;
                return;
            }
        }
        if (f.races.length < MAX_FIXTURE_HORSES / MIN_HORSES_PER_RACE) {
            Race storage newRace = f.races.push();
            newRace.horses.push(horseId);
            newRace.level = lv;
            newRace.length = getRaceLength(lv, 1);
            newRace.startTime = f.startTime + f.races.length * TIME_BETWEEN_RACES;
            newRace.iterations = TOTAL_RACE_ITERATIONS;
        }
    }

    function _compatible(uint256 base, uint256 lv) internal pure returns (bool) {
        if (lv > base) return lv - base <= MAX_LEVELS_DIFFERENCE_TOLERANCE;
        return base - lv <= MAX_LEVELS_DIFFERENCE_TOLERANCE;
    }

    function getRaceLength(uint256 level_, uint256 count) internal pure returns (uint256) {
        uint256 part1 = TOTAL_TRACK_LENGTH / 3;
        uint256 part2 = (TOTAL_TRACK_LENGTH / 3) * (count - MIN_HORSES_PER_RACE) / (MAX_HORSES_PER_RACE - MIN_HORSES_PER_RACE);
        uint256 part3 = (TOTAL_TRACK_LENGTH / 3) * (min(MAX_HORSE_LEVEL_TRACK_MODIFIER, level_) ) / MAX_HORSE_LEVEL_TRACK_MODIFIER;
        return part1 + part2 + part3;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

