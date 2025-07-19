// src/app/game/horse-race.service.ts
import { Injectable, OnDestroy } from '@angular/core';
import { ALL_HORSES, Horse } from './horses-database';
import {
    HorseRace,
    RaceHorsesList,
    HorseRaceState
} from './horse-race.abstract';
import { SlotColor } from './color-database';
import {
    Subject,
    Observable,
    take,
    BehaviorSubject,
    filter
} from 'rxjs';

/**
 * Manages any number of HorseRace instances in a simple array.
 */
class RaceManager {
    private races: HorseRace[] = [];

    constructor(
        private allHorses: Horse[],
        private runnerCount: number,
        private tickMs: number,
        private postSec: number,
    ) {}

    createRace(winDist: number, preSec: number): HorseRace {
        const nextId = this.races.length > 0
            ? this.races[this.races.length - 1].id + 1
            : 1;

        const race = new HorseRace(
            nextId,
            this.allHorses,
            this.runnerCount,
            this.tickMs,
            preSec,
            this.postSec,
            winDist
        );
        this.races.push(race);
        race.startRace();
        return race;
    }

    stopRace(id: number): void {
        this.getHorseRaceById(id).stopRace();
    }

    getRaceState$(id: number): Observable<HorseRaceState> {
        return this.getHorseRaceById(id).raceState$;
    }
    getCountdown$(id: number): Observable<number> {
        return this.getHorseRaceById(id).countdown$;
    }
    getHorsesList$(id: number): Observable<RaceHorsesList> {
        return this.getHorseRaceById(id).horsesList$;
    }
    getWinningDistance(id: number): number {
        return this.getHorseRaceById(id).winningDistance;
    }
    getRaceId(id: number): number {
        return this.getHorseRaceById(id).id;
    }

    getSlotColorMap(id: number): Record<number, SlotColor> {
        return this.getHorseRaceById(id).getSlotColorMap();
    }

    /** Return all IDs in creation order */
    getAllRaceIds(): number[] {
        return this.races.map(r => r.id);
    }

    private getHorseRaceById(id: number): HorseRace {
        const found = this.races.find(r => r.id === id);
        if (!found) {
            throw new Error(`Race ${id} not found`);
        }
        return found;
    }

    stopAll(): void {
        this.races.forEach(r => r.stopRace());
    }
}

@Injectable({ providedIn: 'root' })
export class HorseRaceService implements OnDestroy {
    public manager: RaceManager;
    private destroy$ = new Subject<void>();
    private lastRaceId! : number

    private raceIds$ = new BehaviorSubject<number[]>([]);
    private completedRaceIds = new BehaviorSubject<number[]>([]);

    constructor() {
        this.manager = new RaceManager(
            ALL_HORSES,
            4,     // runners
            100,   // tick interval (ms)
            10,    // post-race countdown (s)
        );

        this.createRaceday()

        // seed ongoingId$ with the first ID that actually exists:
        const ids = this.manager.getAllRaceIds();
        if (ids.length === 0) {
            throw new Error('No races defined');
        }
        this.raceIds$.next(ids);
    }

    getAllRaceIds$(): Observable<number[]> {
        return this.raceIds$.asObservable();
    }

    getCompletedRaceIds$(): Observable<number[]> {
        return this.completedRaceIds.asObservable();
    }

    private createRaceday(): void {
        // create N async races with length and scheduled at a countdown
        // this could be all races for a day, or just a block of races "createRaceBlock()"

        const r1 = this.manager.createRace(2000, 6);
        const r2 = this.manager.createRace(4000, 20);
        const r3 = this.manager.createRace(6000, 40);
        const r4 = this.manager.createRace(2000, 60);
        const r5 = this.manager.createRace(4000, 80);
        const r6 = this.manager.createRace(6000, 100);

        // update compleated races ids list
        [r1, r2, r3, r4, r5, r6].forEach(race => {
            this.manager.getRaceState$(race.id).pipe(
                filter(state => state === 'completed'),
                take(1)
            ).subscribe(() => {
                const updated = [...this.completedRaceIds.value, race.id];
                this.completedRaceIds.next(updated);
            });
        });
        // update race ids list
        this.raceIds$.next(this.manager.getAllRaceIds());

        // create more races when the last one start running (in state)
        this.lastRaceId = r6.id;
        this.manager.getRaceState$(this.lastRaceId).pipe(
            filter(state => state === 'in'),
            take(1)
        ).subscribe(() => {
            this.createRaceday();
        });
    }

    getSlotColorMap(raceId: number): Record<number, SlotColor> {
        return this.manager.getSlotColorMap(raceId);
    }

    ngOnDestroy(): void {
        this.destroy$.next();
        this.manager.stopAll();
    }
}