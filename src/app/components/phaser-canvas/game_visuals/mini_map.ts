// src/app/components/phaser-canvas/game_visuals/mini_map.ts
import Phaser from 'phaser';
import type { HorseRaceService } from '@app/game/horse-race.service';
import { RaceHorsesList } from '@app/game/horse-race.abstract';
import { SlotColor } from '@app/game/color-database';
import { Subscription } from 'rxjs';

export class MiniMapLayer {
    private graphics: Phaser.GameObjects.Graphics;
    private dots = new Map<number, Phaser.GameObjects.Arc>();
    private horsesList!: RaceHorsesList;
    private sub = new Subscription();
    private center!: { x: number; y: number };
    private shape!: StadiumShape;
    private slotColorMap: Record<number, SlotColor> = {};

    private readonly baseWidth    = 100;
    private readonly baseHeight   = 200;
    private readonly trackSpacing = 1;
    private readonly startOffset = 2/12;  // adjust if you want a different 0-pos

    constructor(
        private raceId : number,
        private scene: Phaser.Scene,
        private raceSvc: HorseRaceService,
        private getMarkerOpacity: () => number
    ) {
        this.graphics = this.scene.add.graphics().setDepth(80);

        this.sub.add(
            this.raceSvc.manager.getHorsesList$(this.raceId).subscribe(list => {
                this.horsesList = list;
            })
        );
        
        try {
            this.slotColorMap = this.raceSvc.manager.getSlotColorMap(this.raceId);
        } catch (e) {
            console.error('Failed to get slot color map', this.raceId, e);
        }
        
        this.scene.events.once('shutdown', () => this.destroy());
    }

    create(): void {
        const cam = this.scene.cameras.main;
        this.center = {
            x: cam.worldView.x + cam.width  - this.baseWidth  / 2 - 35,
            y: cam.worldView.y + this.baseHeight / 2 + 25
        };

        // init our shape helper
        this.shape = new StadiumShape(
            this.center,
            this.baseWidth,
            this.baseHeight,
            this.trackSpacing,
            this.startOffset
        );

        // draw each track
        this.graphics.lineStyle(1, 0xffffff, 0.5);
        for (let i = 0; i < 4; i++) {
            this.shape.drawTrack(this.graphics, i);
        }

        // draw start/finish ticks at the top-center
        this.graphics.lineStyle(2, 0xffffff, 1);
        const tickLen = 6;
        for (let i = 0; i < 4; i++) {
            // sample that one point at t=0
            const { x, y } = this.shape.pointOnTrack(i, 0);
            // compute a small perpendicular
            const dx = tickLen;
            this.graphics.beginPath();
            this.graphics.moveTo(x - dx, y);
            this.graphics.lineTo(x + dx, y);
            this.graphics.strokePath();
        }

        // initial dot placement
        this.update();
    }

    update(): void {
        if (!this.horsesList) return;

        const dist = this.raceSvc.manager.getWinningDistance(this.raceId);
        this.horsesList.getAll().forEach(h => {
            const idx = h.slot;
            const totalTracks = 4;  // you’ve hard-coded 4 rings
            // t ∈ [0,1]
            const t = Phaser.Math.Clamp(h.position! / dist, 0, 1);

            // invert so slot 0 → ring 3 (innermost), slot 3 → ring 0 (outermost)
            const ringIndex = (totalTracks - 1) - idx;

            // now sample that ring
            const { x, y } = this.shape.pointOnTrack(ringIndex, t);

            // use the exact HSL—no extra lightness adjust
            const hsl = this.slotColorMap[idx]?.color ?? 'hsl(0,0%,0%)';
            const color = this.hslStringToPhaserColor(hsl, 0);            

            let dot = this.dots.get(idx);
            if (!dot) {
                dot = this.scene.add
                    .arc(x, y, 4, 0, 360, true)
                    .setFillStyle(color)
                    .setDepth(80);
                this.dots.set(idx, dot);
            } else {
                dot.setPosition(x, y)
                    .setFillStyle(color);
            }
        });
    }

    private hslStringToPhaserColor(hslStr: string, adj = 0): number {
        const m = /^hsl\((\d+),\s*(\d+)%?,\s*(\d+)%?\)$/.exec(hslStr);
        if (!m) return 0x000000;
        const h = +m[1] / 360;
        const s = +m[2] / 100;
        let   l = +m[3] / 100;
        l = Phaser.Math.Clamp(l + adj/100, 0, 1);
        return Phaser.Display.Color.HSLToColor(h, s, l).color;
    }

    destroy(): void {
        this.sub.unsubscribe();
        this.graphics.destroy();
        this.dots.forEach(d => d.destroy());
        this.dots.clear();
    }
}

class StadiumShape {
    constructor(
        private center: { x: number; y: number },
        private baseWidth: number,
        private baseHeight: number,
        private trackSpacing: number,
        private startOffset = 2/12  // fraction of perimeter to shift t=0
    ) {}

    /** Draw one track’s outline into `graphics` */
    drawTrack(graphics: Phaser.GameObjects.Graphics, trackIndex: number) {
        const w = this.baseWidth - trackIndex * this.trackSpacing * 2;
        const h = this.baseHeight - trackIndex * this.trackSpacing * 2;
        const R = w / 2;
        const L = h - 2 * R;
        const { x: cx, y: cy } = this.center;
        const topY    = cy - L/2;
        const bottomY = cy + L/2;
        const xLeft   = cx - R;
        const xRight  = cx + R;

        // right straight
        graphics.beginPath();
        graphics.moveTo(xRight, topY);
        graphics.lineTo(xRight, bottomY);
        graphics.strokePath();

        // bottom semicircle (0 → π)
        graphics.beginPath();
        graphics.arc(cx, bottomY, R, 0, Math.PI, false);
        graphics.strokePath();

        // left straight
        graphics.beginPath();
        graphics.moveTo(xLeft, bottomY);
        graphics.lineTo(xLeft, topY);
        graphics.strokePath();

        // top semicircle (π → 2π)
        graphics.beginPath();
        graphics.arc(cx, topY, R, Math.PI, 2 * Math.PI, false);
        graphics.strokePath();
    }

    /**
     * Given a track index and normalized t∈[0,1],
     * returns the {x,y} along that perimeter.
     */
    pointOnTrack(trackIndex: number, t: number): { x: number; y: number } {
        const w = this.baseWidth - trackIndex * this.trackSpacing * 2;
        const h = this.baseHeight - trackIndex * this.trackSpacing * 2;
        const R = w / 2;
        const L = h - 2 * R;
        const P = 2 * L + 2 * Math.PI * R;

        // apply startOffset and clamp
        let u = (t + this.startOffset) % 1;
        u = Phaser.Math.Clamp(u, 0, 1);
        let s = u * P;

        const { x: cx, y: cy } = this.center;
        const topY    = cy - L/2;
        const bottomY = cy + L/2;
        const xLeft   = cx - R;
        const xRight  = cx + R;

        // segment 1: right straight
        if (s <= L) {
            return { x: xRight, y: topY + s };
        }
        s -= L;

        // segment 2: bottom semicircle
        if (s <= Math.PI * R) {
            const θ = s / R;  // 0 → π
            return {
                x: cx + R * Math.cos(θ),
                y: bottomY + R * Math.sin(θ)
            };
        }
        s -= Math.PI * R;

        // segment 3: left straight (going up)
        if (s <= L) {
            return { x: xLeft, y: bottomY - s };
        }
        s -= L;

        // segment 4: top semicircle
        const θ = s / R + Math.PI;  // π → 2π
        return {
            x: cx + R * Math.cos(θ),
            y: topY + R * Math.sin(θ)
        };
    }
}