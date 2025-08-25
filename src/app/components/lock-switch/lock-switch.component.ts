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
    @Input() lockedText: string = '';
    @Input() unlockedText: string = '';

    // Internal value driven by writeValue / NgModel (child) / onChange
    current_state = false;

    // Disabled flag propagated by Angular Forms
    is_disabled = false;

    // Callbacks provided by Angular Forms
    private onChange: (value: boolean) => void = () => {};
    private onTouched: () => void = () => {};

    get isLocked() {
        return !this.current_state;
    }

    // ---- ControlValueAccessor API ----
    writeValue(value: boolean): void {
        this.current_state = !value;
    }

    registerOnChange(fn: (value: boolean) => void): void {
        this.onChange = fn;
    }

    registerOnTouched(fn: () => void): void {
        this.onTouched = fn;
    }

    setDisabledState(isDisabled: boolean): void {
        this.is_disabled = isDisabled;
    }
    // ----------------------------------

    // Called when child toggleswitch changes
    onToggleChange(value: boolean): void {
        this.current_state = !!value;
        this.onChange(this.isLocked); // notify parent form about value change
        this.onTouched(); // mark as touched
    }

    // Optional: clicking the text also toggles
    toggle(): void {
        if (this.is_disabled) {
            return;
        }
        this.onToggleChange(!this.current_state);
    }
}
