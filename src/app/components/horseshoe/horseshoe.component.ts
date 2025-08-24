import { Component, Input } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { StatsPack } from '@app/types';
import { ProgressBarModule } from 'primeng/progressbar';
import { StatsComponent } from '../stats/stats.component';

@Component({
    selector: 'app-horseshoe',
    standalone: true,
    imports: [
        SharedModule,
        ProgressBarModule,
        StatsComponent,
    ],
    templateUrl: './horseshoe.component.html',
    styleUrls: ['./horseshoe.component.scss'],
})
export class HorseshoeComponent {
    @Input() statspack: StatsPack;

    constructor(
    ) {}

}
