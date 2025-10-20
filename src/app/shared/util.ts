export function getHorseImageUrl(imgCategory: number, imgNumber: number): string {
    const numberStr = imgNumber.toString().padStart(3, '0');
    let category = 'unknown';
    switch (imgCategory) {
        case 0:
            category = 'default';
            break;
        default:
            console.error(`Unknown image category: ${imgCategory}`);
            break;
    }
    return `horses/${category}/horse-${numberStr}.png`;
}