// src/app/components/phaser-canvas/game_visuals/race_line.ts
import Phaser from 'phaser';
import { RaceHorsesList, HorseRaceState } from '@app/game/horse-race.abstract';
import { SlotColor } from '@app/game/color-database';
import { HorseRaceService } from '@app/game/horse-race.service';
import { Subscription } from 'rxjs';

export class RaceLineLayer {
    private cam: Camera;
    private neededSkins: Set<string> = new Set();
    private neededJockeys: Set<string> = new Set();
    
    constructor(
        private raceId : number,
        private scene: Phaser.Scene,
        private horseRaceService: HorseRaceService,
        private getMarkerOpacity: () => number,
        private getPlacementFollow: () => number,
        private getHorseFollow: () => number,
        private getFollowHorse: () => Boolean,
    ) {
        this.cam = new Camera(
            this.raceId,
            this.scene,
            this.horseRaceService,
            this.getMarkerOpacity,
            this.getPlacementFollow,
            this.getHorseFollow,
            this.getFollowHorse,
            (skins: string[]) => skins.forEach(s => this.neededSkins.add(s)),
            (jockeys: string[]) => jockeys.forEach(j => this.neededJockeys.add(j))
        );
    
        this.scene.events.once('shutdown', () => this.destroy());
    }

    public getCamPos = () => this.cam.pos;

    preload(): void {
        this.scene.load.image('img_final_post', 'assets/game-img/sprite-sheet/finish-post.png');
        this.scene.load.image('img_start_gate', 'assets/game-img/sprite-sheet/starting-gate.png');
    
        for (const jockey of this.neededJockeys) {
            this.scene.load.spritesheet(
                `jockeySpriteSheet-${jockey}`,
                `assets/game-img/sprite-sheet/split/split-jockey-${jockey}.png`,
                { frameWidth: 575, frameHeight: 434 }
            );
        }
    
        for (const skin of this.neededSkins) {
            this.scene.load.spritesheet(
                `overlay-${skin}`,
                `assets/game-img/sprite-sheet/split/split-horse-${skin}.png`,
                { frameWidth: 575, frameHeight: 434 }
            );
        }
    }

    create(): void {
        this.cam.updateCam();
    }

    update(time: number, delta: number): void {
        this.cam.updateCam();
    }

    /** clean up subscription & graphics */
    destroy(): void {
        this.cam.destroy();
    }
}

class Camera {
    public pos = 0;
    public origin: { x: number; y: number };
    private graphics: Phaser.GameObjects.Graphics;
    private posToPx = 15;
    private raceSvc: HorseRaceService;
    private horsesList!: RaceHorsesList;
    private raceState: HorseRaceState = 'pre';
    private slotColorMap: Record<number, SlotColor> = {};
    private sub = new Subscription();
    private images: Map<string, Phaser.GameObjects.Image> = new Map();
    private sprites: Map<string, Phaser.GameObjects.Sprite> = new Map();
    private shadows: Map<string, Phaser.GameObjects.Ellipse> = new Map();
    private composites: Map<string, CompositeHorse> = new Map();

    constructor(
        private raceId : number,
        private scene: Phaser.Scene,
        raceSvc: HorseRaceService,
        private getMarkerOpacity: () => number,
        private getPlacementFollow: () => number,
        private getHorseFollow: () => number,
        private getFollowHorse: () => Boolean,
        private reportNeededSkins: (skins: string[]) => void,
        private reportNeededJockeys: (jockeyNames: string[]) => void,
        origin?: { x: number; y: number }
    ) {
        this.raceSvc = raceSvc;
        this.origin = origin ?? { x: 0.5, y: 0.5 };
        this.graphics = this.scene.add.graphics();

        // add both subscriptions to the composite
        this.sub.add(
            this.raceSvc.manager.getHorsesList$(this.raceId).subscribe(list => {
                this.horsesList = list;
                // collect skins and report back
                const skins = list.getAll().map(h => h.horse.skin);
                this.reportNeededSkins([...new Set(skins)]);        
            })
        );
        this.sub.add(
            this.raceSvc.manager.getRaceState$(this.raceId).subscribe(state => {
                this.raceState = state;
            })
        );
        try {
            this.slotColorMap = this.raceSvc.manager.getSlotColorMap(this.raceId);
            const jockeyNames = [...new Set(Object.values(this.slotColorMap).map(c => c.name))];
            this.reportNeededJockeys(jockeyNames);
        } catch (e) {
            console.error('Failed to load slot color map for race', this.raceId, e);
        }
    }

    updateCam(): void {
        // Set cam game position
        const placementFollow: number = this.getPlacementFollow() // placment from 0 to 3
        const horseFollow: number = this.getHorseFollow() // horse slot from 0 to 3
        const followHorse: Boolean = this.getFollowHorse() // if true uses horseFollow

        const placement = this.horsesList.getByPlacement()[placementFollow].position;
        const horse = this.horsesList.getAll()[horseFollow].position;

        if (followHorse == false) {
            this.pos = placement
        }else {this.pos = horse}

        // camera stops at final winning post
        if (this.pos >= this.raceSvc.manager.getWinningDistance(this.raceId)) {
            this.pos = this.raceSvc.manager.getWinningDistance(this.raceId);
        }

        // interpolate origin.x between start(0.5) and finalOrigin
        const finalOriginX = 0.63;
        const progress    = Phaser.Math.Clamp(this.pos / this.raceSvc.manager.getWinningDistance(this.raceId), 0, 1);
        this.origin.x     = Phaser.Math.Interpolation.Linear([0.5, finalOriginX], progress);

        // Calculate and draw cam point of view
        this.graphics.setDepth(100); // apply depth to current graphics(Cross and Points)
        this.drawView();
    }

    private drawView(): void {
        this.graphics.clear();

        // Draw camera cross
        this.drawCamCross();

        // Draw race end
        this.drawCamImg(this.raceSvc.manager.getWinningDistance(this.raceId), 'img_final_post', 'p0', 0.14, -18, 0, 0);

        // Draw race start
        this.drawCamImg(0, 'img_start_gate', 'g0', 0.20, 0, -110, 1);
        this.drawCamImg(0, 'img_start_gate', 'g1', 0.20, 12, -110, 3);
        this.drawCamImg(0, 'img_start_gate', 'g2', 0.20, 24, -110, 5);
        this.drawCamImg(0, 'img_start_gate', 'g3', 0.20, 36, -110, 10);

        // Draw race horses
        this.horsesList.getAll().forEach((h, index) => {
            if (h.position != null) {
                const hsl = this.slotColorMap[h.slot]?.color ?? 'hsl(0,0%,0%)';
                const color = this.hslStringToPhaserColor(hsl, 25);
                this.drawCamPoint(h.position, color);

                const jockeyColor = this.slotColorMap[h.slot]?.name ?? 'black';
                const spriteSheetKey = `jockeySpriteSheet-${jockeyColor}`;
                const instanceId     = `horse${index}`;
                const offsetY        = 18 + index * 10;
                const offsetX        = -90;
                const depth          = index * 2;
                const frameRate      = 18 + index;
                const idle           = this.raceState === 'pre';

                this.drawCamHorse(
                    h.position,
                    spriteSheetKey,
                    instanceId,
                    0.35,
                    offsetY,
                    offsetX,
                    depth,
                    frameRate,
                    idle
                );
            }
        });
    }

    // FUNCS TO DRAW RACE OBJECTS
    private drawCamCross(): void {
        const cam    = this.scene.cameras.main;
        const worldX = cam.worldView.x + cam.width * this.origin.x;
        const worldY = cam.worldView.y + cam.height * this.origin.y;
        const size   = 6;

        this.graphics.lineStyle(2, 0x0f0f0f, 0.9);
        this.graphics.beginPath();
        this.graphics.moveTo(worldX - size, worldY);
        this.graphics.lineTo(worldX + size, worldY);
        this.graphics.moveTo(worldX, worldY - size);
        this.graphics.lineTo(worldX, worldY + size);
        this.graphics.strokePath();
    }

    private drawCamPoint(pointPos: number, color: number = 0x00ff00): void {
        const cam     = this.scene.cameras.main;
        const worldX0 = cam.worldView.x + cam.width * this.origin.x;
        const worldY0 = cam.worldView.y + cam.height * this.origin.y;

        const deltaX = (pointPos - this.pos) * this.posToPx;
        const x      = worldX0 + deltaX;
        const y      = worldY0 + 118;

        this.graphics.fillStyle(color, this.getMarkerOpacity());
        this.graphics.fillRect(x, y, 2, 8);
    }

    private drawCamImg(
        pointPos: number,
        imgKey: string,
        instanceId: string = imgKey,
        scale = 0.5,
        offsetY = 0,
        offsetX = 0,
        depth = 1,
    ): void {
        const cam     = this.scene.cameras.main;
        const worldX0 = cam.worldView.x + cam.width * this.origin.x;
        const worldY0 = cam.worldView.y + cam.height * this.origin.y;
        const deltaX  = (pointPos - this.pos) * this.posToPx;
        const x       = worldX0 + deltaX + offsetX;
        const y       = worldY0 + offsetY;
        const key     = `img:${instanceId}`;
        let img       = this.images.get(key);

        if (!img) {
            img = this.scene.add.image(x, y, imgKey)
                .setScale(scale)
                .setDepth(depth);
            this.images.set(key, img);
        } else {
            img.setPosition(x, y).setDepth(depth);
        }
    }

    private drawCamHorse(
        pointPos: number,
        spriteSheetKey: string,
        instanceId: string,
        scale = 0.15,
        offsetY = 0,
        offsetX = 0,
        depth = 1,
        frameRate = 19,
        idle = false,
        shadowOffsetX = -15,
        shadowOffsetY = 70
    ): void {
        const finalSlideSpeed = 25;
        const cam = this.scene.cameras.main;
        const worldX0 = cam.worldView.x + cam.width * this.origin.x;
        const worldY0 = cam.worldView.y + cam.height * this.origin.y;
        const deltaX = (pointPos - this.pos) * this.posToPx;
        const initialTargetX = worldX0 + deltaX + offsetX;
        const y = worldY0 + offsetY;
        const key = `composite:${instanceId}`;
        const animKey = `run:${spriteSheetKey}`;
        const horse = this.horsesList.getAll()[parseInt(instanceId.replace('horse', ''))];
        const overlayKey = `overlay-${horse.horse.skin}`;
    
        let composite = this.composites.get(key);
        if (!composite) {
            const container = this.scene.add.container();
            composite = new CompositeHorse(
                this.scene,
                container,
                spriteSheetKey,
                overlayKey,
                animKey,
                scale,
                depth,
                frameRate
            );
            composite.spawn(initialTargetX, y, idle);
            this.composites.set(key, composite);
    
            // optional shadow
            const shadow = this.scene.add.ellipse(
                initialTargetX + shadowOffsetX,
                y + shadowOffsetY,
                140,
                12,
                0x000000,
                0.4
            ).setScale(1, 0.5).setDepth(depth - 0.5);
            this.shadows.set(key, shadow);
        } else {
            if (this.pos >= this.raceSvc.manager.getWinningDistance(this.raceId)) {
                composite.update(composite.base.x + finalSlideSpeed, y, idle);
            } else {
                const dx = initialTargetX - composite.base.x;
                const nextX = composite.base.x + (Math.abs(dx) > 1 ? dx * 0.04 : 0);
                composite.update(nextX, y, idle);
            }
    
            const shadow = this.shadows.get(key)!;
            shadow.x = composite.base.x + shadowOffsetX;
            shadow.y = y + shadowOffsetY;
            shadow.setDepth(depth - 0.5);
        }
    }
    

    /** parse “hsl( … )” into a Phaser-friendly color integer */
    private hslStringToPhaserColor(hslStr: string, lightnessAdjust = 0): number {
        const match = /^hsl\((\d+),\s*(\d+)%?,\s*(\d+)%?\)$/.exec(hslStr);
        if (!match) {
            return 0x000000;
        }
        const h = parseInt(match[1], 10) / 360;
        const s = parseInt(match[2], 10) / 100;
        let   l = parseInt(match[3], 10) / 100;
        l = Phaser.Math.Clamp(l + lightnessAdjust / 100, 0, 1);
        return Phaser.Display.Color.HSLToColor(h, s, l).color;
    }

    /** tear down subscription and graphics */
    destroy(): void {
        this.sub.unsubscribe();
        this.graphics.destroy();
        this.images.forEach(img => img.destroy());
        this.images.clear();
        this.sprites.forEach(sprite => sprite.destroy());
        this.sprites.clear();
        this.shadows.forEach(shadow => shadow.destroy());
        this.shadows.clear();
        this.composites.forEach(comp => comp.destroy());
        this.composites.clear();
    }
}

class CompositeHorse {
    public base!: Phaser.GameObjects.Sprite;
    public overlay!: Phaser.GameObjects.Sprite;
    private overlayAnimKey!: string;

    constructor(
        private scene: Phaser.Scene,
        private container: Phaser.GameObjects.Container,
        private baseKey: string,
        private overlayKey: string,
        private animKey: string,
        private scale: number,
        private depth: number,
        private frameRate: number
    ) {}

    private ensureAnim() {
        // Base animation
        if (!this.scene.anims.exists(this.animKey)) {
            this.scene.anims.create({
                key: this.animKey,
                frames: this.scene.anims.generateFrameNumbers(this.baseKey),
                frameRate: this.frameRate,
                repeat: -1
            });
        }

        // Overlay animation
        this.overlayAnimKey = `${this.animKey}__overlay`;
        if (!this.scene.anims.exists(this.overlayAnimKey)) {
            this.scene.anims.create({
                key: this.overlayAnimKey,
                frames: this.scene.anims.generateFrameNumbers(this.overlayKey),
                frameRate: this.frameRate,
                repeat: -1
            });
        }
    }

    spawn(x: number, y: number, idle: boolean) {
        this.ensureAnim();

        this.base = this.scene.add.sprite(x, y, this.baseKey)
            .setScale(this.scale)
            .setDepth(this.depth);

        this.overlay = this.scene.add.sprite(x, y, this.overlayKey)
            .setScale(this.scale)
            .setDepth(this.depth + 0.01);

        this.container.add([this.base, this.overlay]);

        if (!idle) {
            this.base.play(this.animKey);
            this.overlay.play(this.overlayAnimKey);
        } else {
            this.base.setFrame(3);
            this.overlay.setFrame(3);
        }
    }

    update(x: number, y: number, idle: boolean) {
        this.base.setPosition(x, y);
        this.overlay.setPosition(x, y);

        if (idle) {
            this.base.anims.stop();
            this.overlay.anims.stop();
            this.base.setFrame(3);
            this.overlay.setFrame(3);
        } else if (!this.base.anims.isPlaying) {
            this.base.play(this.animKey);
            this.overlay.play(this.overlayAnimKey);
        }
    }

    destroy() {
        this.base.destroy();
        this.overlay.destroy();
    }
}

