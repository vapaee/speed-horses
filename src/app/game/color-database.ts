// src/app/game/color-database.ts
export interface SlotColor {
    index: number;
    name: string;    // used as part of the sprite file name
    color: string;   // HSL format
}

// ONLY use colors that match existing split-jockey-*.png assets for now
export const ALL_COLORS: SlotColor[] = [
    { index: 0, name: 'red',     color: 'hsl(0,70%,30%)' },
    { index: 1, name: 'green',   color: 'hsl(120,70%,30%)' },
    { index: 2, name: 'black',   color: 'hsl(0,0%,10%)' },
    { index: 3, name: 'magenta', color: 'hsl(300,70%,30%)' },
    { index: 4, name: 'cyan',    color: 'hsl(180,70%,30%)' },
    { index: 5, name: 'orange',    color: 'hsl(25,70%,35%)' },
    { index: 6, name: 'blue',    color: 'hsl(210,70%,30%)' },
    { index: 7, name: 'yellow',    color: 'hsl(50, 70%, 35%)' },
    // ...
];