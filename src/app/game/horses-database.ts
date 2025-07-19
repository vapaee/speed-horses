// src/app/data/horses-database.ts
export interface Horse {
    index:   number;
    name:    string;
    skin: string;
}

export const ALL_HORSES: Horse[] = [
    { index:  1,  name: 'Fast Fury', skin: 'creme'},
    { index:  2,  name: 'Gengis Run', skin: 'brown-light'},
    { index:  3,  name: 'Silver Arrow', skin: 'gray-blue'},
    { index:  4,  name: 'Wind Chaser', skin: 'white-ghost'},
    { index:  5,  name: 'Storm Bringer', skin: 'brown-dark'},
    { index:  6,  name: 'Lightning Bolt', skin: 'creme'},
    { index:  7,  name: 'Tony Hoof', skin: 'black'},
    { index:  8,  name: 'Lucky Star', skin: 'brown'},
    { index:  9,  name: 'Shadow Dancer', skin: 'black'},
    { index: 10,  name: 'Thunder Strike', skin: 'brown-light'},
    { index: 11,  name: 'Moonlight Mare', skin: 'gray-blue'},
    { index: 12,  name: 'Open Republic', skin: 'white-ghost'},
    { index: 13,  name: 'Majestic Wind', skin: 'brown'},
    { index: 14,  name: 'Night Rider', skin: 'black'},
    { index: 15,  name: 'Crimson Trail', skin: 'brown-dark'},
    { index: 16,  name: 'Harry Sprint', skin: 'brown-light'},
    { index: 17,  name: 'Sapphire Skies', skin: 'white-ghost'},
    { index: 18,  name: 'Onyx Spirit', skin: 'black'},
    { index: 19,  name: 'Diamond Dancer', skin: 'gray-blue'},
    { index: 20,  name: 'Celestial Runner', skin: 'white-ghost'},
    { index: 21,  name: 'Babe Michelangelo', skin: 'creme'},
];