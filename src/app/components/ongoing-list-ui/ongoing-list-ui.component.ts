import {
    Component,
    AfterViewInit,
    OnDestroy,
    ViewChildren,
    QueryList,
    ElementRef,
    Renderer2,
    NgZone,
    Input,
    SimpleChanges,
    Output,
    EventEmitter
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { BreakpointObserver } from '@angular/cdk/layout';
import { Subject, takeUntil } from 'rxjs';
import { HorseRaceService } from '@app/game/horse-race.service';
import { RaceHorse, RaceHorsesList } from '@app/game/horse-race.abstract';
import { SlotColor } from '@app/game/color-database';
import { RaceHorseUiComponent } from '@app/components/ongoing-horse-ui/ongoing-horse-ui.component';
import { BREAKPOINT } from 'src/types';

@Component({
    standalone: true,
    selector: 'app-ongoing-list-ui',
    imports: [CommonModule, RaceHorseUiComponent],
    templateUrl: './ongoing-list-ui.component.html',
    styleUrls: ['./ongoing-list-ui.component.scss']
})
export class OngoingListUiComponent implements AfterViewInit, OnDestroy {
    @Input() raceId!: number;
    @Input() selectedHorse?: number;
    @Input() isFollowingHorse = false;
    @Output() horseSelected = new EventEmitter<number>();

    horsesList: RaceHorse[] = [];
    isMobileView = false;
    slotColorMap: Record<number, SlotColor> = {};

    private lastListInstance?: RaceHorsesList;
    private destroy$ = new Subject<void>();
    private prevY = new Map<number, number>();

    @ViewChildren('horseTrack', { read: ElementRef })
    horseElems!: QueryList<ElementRef>;

    constructor(
        private horseRaceService: HorseRaceService,
        private breakpointObserver: BreakpointObserver,
        private renderer: Renderer2,
        private ngZone: NgZone
    ) {
        this.breakpointObserver
            .observe(BREAKPOINT)
            .pipe(takeUntil(this.destroy$))
            .subscribe(r => this.isMobileView = r.matches);
    }

    ngOnChanges(changes: SimpleChanges): void {
        if ('raceId' in changes && this.raceId != null) {
            try {
                this.slotColorMap = this.horseRaceService.getSlotColorMap(this.raceId);
                
                this.horseRaceService
                    .manager.getHorsesList$(this.raceId)
                    .pipe(takeUntil(this.destroy$))
                    .subscribe(listInstance => {
                        if (listInstance !== this.lastListInstance) {
                            this.lastListInstance = listInstance;
                        }

                        const newList = listInstance.getByPlacement();

                        // Always update the list (even if empty)
                        this.horsesList = newList;

                        // If it's empty, just return (don't FLIP yet)
                        if (newList.length === 0) return;

                        this.recordPositions();

                        // Wait for DOM update, then run FLIP
                        requestAnimationFrame(() => this.runFLIP());
                });

            } catch (err) {
                console.error('Invalid race ID', this.raceId, err);
            }
        }
    }


    ngAfterViewInit(): void {
        this.recordPositions();
    }

    ngOnDestroy(): void {
        this.destroy$.next();
        this.destroy$.complete();
    }

    private recordPositions(): void {
        this.prevY.clear();
        this.horseElems.forEach(el => {
            const idx = +el.nativeElement.dataset.index;
            const { top: y } = el.nativeElement.getBoundingClientRect();
            this.prevY.set(idx, y);
        });
    }

    private runFLIP(): void {
        const oldYMap = new Map(this.prevY);

        this.ngZone.runOutsideAngular(() => {
            const newYMap = new Map<number, number>();

            this.horseElems.forEach(el => {
                const idx = +el.nativeElement.dataset.index;
                const { top } = el.nativeElement.getBoundingClientRect();
                const y = top + window.pageYOffset;
                newYMap.set(idx, y);
            });

            this.horseElems.forEach(el => {
                const idx = +el.nativeElement.dataset.index;
                const oldY = oldYMap.get(idx);
                const newY = newYMap.get(idx);
                if (oldY == null || newY == null) return;

                const deltaY = oldY - newY;
                if (deltaY) {
                    this.renderer.setStyle(el.nativeElement, 'transition', 'none');
                    this.renderer.setStyle(el.nativeElement, 'transform', `translateY(${deltaY}px)`);
                }
            });

            // Force reflow
            this.horseElems.first?.nativeElement.getBoundingClientRect();

            requestAnimationFrame(() => {
                this.horseElems.forEach(el => {
                    const idx = +el.nativeElement.dataset.index;
                    const oldY = oldYMap.get(idx);
                    const newY = newYMap.get(idx);
                    if (oldY != null && newY != null && oldY !== newY) {
                        this.renderer.setStyle(el.nativeElement, 'transition', 'transform 200ms linear');
                        this.renderer.setStyle(el.nativeElement, 'transform', 'translateY(0)');
                    }
                });

                // Capture next baseline immediately after FLIP completes
                setTimeout(() => this.recordPositions(), 200); // match transition time
            });
        });
    }


    getColor(slot: number): string {
        return this.slotColorMap[slot]?.color ?? 'black';
    }
}
