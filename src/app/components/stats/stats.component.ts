import { Component, Input } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { Stats, StatsPack } from '@app/types';
import { ProgressBarModule } from 'primeng/progressbar';

@Component({
    selector: 'app-stats',
    standalone: true,
    imports: [
        SharedModule,
        ProgressBarModule,
    ],
    templateUrl: './stats.component.html',
    styleUrls: ['./stats.component.scss'],
})
export class StatsComponent {
    @Input() statspack: StatsPack;

    constructor(
    ) {}

    percent(value: number) {
        return 100 * value / this.statspack.total;
    }
}
