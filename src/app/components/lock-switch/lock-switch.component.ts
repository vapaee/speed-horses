import { Component, Input, forwardRef } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
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
    styleUrls: ['./lock-switch.component.scss'],
    providers: [
        {
            provide: NG_VALUE_ACCESSOR,
            useExisting: forwardRef(() => LockSwitchComponent),
            multi: true
        }
    ]
})
export class LockSwitchComponent implements ControlValueAccessor {
    @Input() lockedText: string;
    @Input() unlockedText: string;

    current_state = false;

    private onChange: (value: boolean) => void = () => {};
    private onTouched: () => void = () => {};

    writeValue(value: boolean): void {
        this.current_state = value;
    }

    registerOnChange(fn: (value: boolean) => void): void {
        this.onChange = fn;
    }

    registerOnTouched(fn: () => void): void {
        this.onTouched = fn;
    }

    onToggleChange(value: boolean): void {
        this.current_state = value;
        this.onChange(value);
        this.onTouched();
    }

    toggle(): void {
        this.onToggleChange(!this.current_state);
    }
}

