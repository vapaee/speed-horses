// src/app/components/phaser-canvas/phaser-canvas.component.ts
import {
    Component,
    OnInit,
    OnDestroy,
    ElementRef,
    ViewChild,
    Input
} from '@angular/core';
import Phaser from 'phaser';
import { MainScene } from './game_visuals/main_scene';
import { BreakpointObserver } from '@angular/cdk/layout';
import { BREAKPOINT } from 'src/types';
import { Observable, Subscription } from 'rxjs';
import { map } from 'rxjs/operators';
import { HorseRaceService } from '@app/game/horse-race.service';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ExpandableComponent } from '../base-components/expandable/expandable.component';

@Component({
    selector: 'app-phaser-canvas',
    templateUrl: './phaser-canvas.component.html',
    styleUrls: ['./phaser-canvas.component.scss'],
    standalone: true,
    imports: [
        CommonModule,
        FormsModule,
        ExpandableComponent
    ]
})
export class PhaserCanvasComponent implements OnInit, OnDestroy {
    @ViewChild('phaserContainer', { static: true })
    containerRef!: ElementRef;
    @Input() raceId!: number;

    isMobileView$: Observable<boolean>;

    markerOpacity = 0;
    lightnessValue = 0.1;
    placementFollow = 0;
    horseFollow = 0;
    followHorse = false;
    isMuted = true;

    private game?: Phaser.Game;

    constructor(
        private breakpointObserver: BreakpointObserver,
        private horseRaceService: HorseRaceService
    ) {
        this.isMobileView$ = this.breakpointObserver
            .observe(BREAKPOINT)
            .pipe(map(result => result.matches));
    }

    ngOnInit(): void {
        this.startGame();
    }

    ngOnDestroy(): void {
        // destroy Phaser
        this.game?.destroy(true);
    }

    private startGame(): void {
        // instantiate the scene
        const scene = new MainScene(
            this.raceId,
            this.horseRaceService,
            () => this.markerOpacity,
            () => this.lightnessValue,
            () => this.placementFollow,
            () => this.horseFollow,
            () => this.followHorse,
            () => this.isMuted
        );
        // boot Phaser
        this.game = new Phaser.Game({
            type: Phaser.AUTO,
            width: 1000,
            height: 250,
            parent: this.containerRef.nativeElement,
            scene,
            input: {
                // allow wheel to bubble so the page can scroll
                mouse: {
                    preventDefaultWheel: false
                },
                // stop Phaser from doing event.preventDefault() on touch
                touch: {
                    capture: false
                }
            }
        });
    }

    setPlacementFollow(index: number) {
        const horseCount = 4;
        const normalized = ((index % horseCount) + horseCount) % horseCount;
        this.placementFollow = normalized;
        this.followHorse = false;
    }

    setHorseFollow(index: number) {
        const horseCount = 4;
        const normalized = ((index % horseCount) + horseCount) % horseCount;
        this.horseFollow = normalized;
        this.followHorse = true;
    }
}
