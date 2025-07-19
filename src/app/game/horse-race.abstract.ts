// src/app/game/horse-race.abstract.ts
import { BehaviorSubject, interval, Subscription } from 'rxjs';
import { Horse } from './horses-database';
import { ALL_COLORS, SlotColor } from './color-database';

export interface RaceHorse {
    slot:             number;
    horse:            Horse;
    position:     number;
    finalPlace: number | null;
}

export class RaceHorsesList {
    private list: RaceHorse[];

    constructor(allHorses: Horse[], private count: number) {
        const selected = this.shuffle(allHorses).slice(0, count);
        this.list = selected.map((h, i) => ({
            slot:                i,
            horse:             h,
            position:        0,
            finalPlace:    null
        }));
    }

    private shuffle(arr: Horse[]): Horse[] {
        const a = [...arr];
        for (let i = a.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [a[i], a[j]] = [a[j], a[i]];
        }
        return a;
    }

    getAll(): RaceHorse[] {
        return [...this.list];
    }

    getByPlacement(): RaceHorse[] {
        return [...this.list].sort((a, b) => {
            if (a.finalPlace != null && b.finalPlace != null) {
                return a.finalPlace - b.finalPlace;
            }
            if (a.finalPlace != null) return -1;
            if (b.finalPlace != null) return 1;
            return b.position! - a.position!;
        });
    }

    applyAdvances(advances: number[], winningDistance: number): number {
        let finishCount = this.list.filter(h => h.finalPlace! > 0).length;
        const prePositions = this.list.map(h => h.position!);

        this.list.forEach((h, i) => {
            h.position! += advances[i] || 0;
        });

        const newFinishers = this.list
            .filter(h => h.finalPlace == null && h.position! >= winningDistance)
            .sort((A, B) => {
                const overA = A.position! - winningDistance;
                const overB = B.position! - winningDistance;
                if (overB !== overA) return overB - overA;
                const iA = this.list.indexOf(A), iB = this.list.indexOf(B);
                return prePositions[iB] - prePositions[iA];
            });

        newFinishers.forEach(h => h.finalPlace = ++finishCount);
        return finishCount;
    }

    consoleLog(): void {
        console.log('');
        this.list.forEach(h => {
            console.log(
                `Horse ${h.horse.index} — pos: ${h.position} — Place: ${h.finalPlace}`
            );
        });
    }
}

class Seed {
    private seedValue: number;
    private readonly allowed = [6, 7, 8, 9];
    constructor(private length: number) {
        this.seedValue = this.gen();
    }
    private gen(): number {
        let s = '';
        for (let i = 0; i < this.length; i++) {
            s += this.allowed[Math.floor(Math.random() * this.allowed.length)];
        }
        return +s;
    }
    splitNumber(parts: number): number[] {
        const digs = this.seedValue.toString().split('');
        const size = Math.floor(digs.length / parts);
        if (!size) return [];
        const out: number[] = [];
        for (let i = 0; i < parts; i++) {
            const chunk = digs.slice(i * size, (i + 1) * size);
            if (chunk.length === size) out.push(+chunk.join(''));
        }
        return out;
    }
}

class CountdownTimer {
    private interval$?: Subscription;
    private _countdown = new BehaviorSubject<number>(0);

    get countdown$() {
        return this._countdown.asObservable();
    }

    start(
        seconds: number,
        onComplete: () => void,
        external?: BehaviorSubject<number>
    ): void {
        // if there’s already a timer, stop it first
        this.interval$?.unsubscribe();

        // initialize
        this._countdown.next(seconds);
        external?.next(seconds);

        this.interval$ = interval(1000).subscribe(() => {
            const curr = this._countdown.getValue();
            const next = Math.max(0, curr - 1);      // clamp at 0
            this._countdown.next(next);
            external?.next(next);

            if (next === 0) {
                this.interval$?.unsubscribe();       // tear down timer
                onComplete();
            }
        });
    }

    stop(): void {
        this.interval$?.unsubscribe();
    }
}

export type HorseRaceState = 'pre' | 'in' | 'post' | 'completed';

export class HorseRace {
    readonly id: number;
    readonly winningDistance: number;
    completed = false;
    private slotColorMap: Record<number, SlotColor> = {};

    private readonly tickSpeed:    number;
    private readonly preDuration:  number;
    private readonly postDuration: number;
    private readonly allHorses:    Horse[];
    private readonly count:        number;

    private raceSub?:   Subscription;
    private preTimer    = new CountdownTimer();
    private postTimer   = new CountdownTimer();

    private _list$      = new BehaviorSubject<RaceHorsesList>(new RaceHorsesList([], 0));
    private _state$     = new BehaviorSubject<HorseRaceState>('pre');
    private _cnt$       = new BehaviorSubject<number>(0);

    readonly horsesList$ = this._list$.asObservable();
    readonly raceState$  = this._state$.asObservable();
    readonly countdown$  = this._cnt$.asObservable();

    constructor(
        id: number,
        allHorses: Horse[],
        count: number,
        tickSpeed   = 100,
        preSec      = 20,
        postSec     = 10,
        distanceDm  = 2000
    ) {
        this.id               = id;
        this.allHorses        = allHorses;
        this.count            = count;
        this.tickSpeed        = tickSpeed;
        this.preDuration      = preSec;
        this.postDuration     = postSec;
        this.winningDistance  = distanceDm;
    }

    startRace(): void {
        // reset completed flag each time we start
        this.completed = false;
        this.stopRace();
        console.log(`race ${this.id} started`);
        this._list$.next(new RaceHorsesList(this.allHorses, this.count));
        this.slotColorMap = this.generateSlotColorMap(this.count);
        this._state$.next('pre');
        this.preTimer.start(
            this.preDuration,
            () => this.begin(),
            this._cnt$
        );
    }

    private begin(): void {
        this._state$.next('in');
        this.raceSub = interval(this.tickSpeed).subscribe(() => {
            const list     = this._list$.getValue();
            const seed     = new Seed(this.count);
            const advances = seed.splitNumber(list.getAll().length);
            const finished = list.applyAdvances(advances, this.winningDistance);

            this._list$.next(list);
            // list.consoleLog();

            if (finished === list.getAll().length) {
                // stop the racing ticks right away
                this.raceSub?.unsubscribe();
                // switch UI into 'post'
                this._state$.next('post');
                // start the post-race countdown just once
                this.postTimer.start(
                    this.postDuration,
                    () => this.raceCompleted(),
                    this._cnt$
                );
            }
        });
    }

    /** Called when post‐timer reaches zero */
    raceCompleted(): void {
        // stop any leftover timers (though raceSub is already gone)
        this.stopRace();
        this._state$.next('completed');
        console.log(`race ${this.id} finished`);
    }

    stopRace(): void {
        this.raceSub?.unsubscribe();
        this.preTimer.stop();
        this.postTimer.stop();
    }

    getSlotColorMap(): Record<number, SlotColor> {
        return this.slotColorMap;
    }

    private generateSlotColorMap(count: number): Record<number, SlotColor> {
        const shuffled = [...ALL_COLORS];
        for (let i = shuffled.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
        }
        return Object.fromEntries(
            shuffled.slice(0, count).map((c, i) => [i, c])
        );
    }
}
