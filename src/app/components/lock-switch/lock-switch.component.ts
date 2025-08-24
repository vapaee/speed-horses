import { Component, Input, Output } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { ProgressBarModule } from 'primeng/progressbar';
import { ToggleSwitchModule } from 'primeng/toggleswitch';

@Component({
    selector: 'app-lock-switch',
    standalone: true,
    imports: [
        SharedModule,
        ProgressBarModule,
        ToggleSwitchModule
    ],
    templateUrl: './lock-switch.component.html',
    styleUrls: ['./lock-switch.component.scss']
})
export class LockSwitchComponent {
    @Input() lockedText: string;
    @Input() unlockedText: string;
    current_state = false;
}

