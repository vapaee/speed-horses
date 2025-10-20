import { Component, EventEmitter, Input, Output } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    selector: 'app-confirm-dialog',
    standalone: true,
    imports: [SharedModule],
    templateUrl: './confirm-dialog.component.html',
    styleUrls: ['./confirm-dialog.component.scss']
})
export class ConfirmDialogComponent {
    @Input() title: string = '';
    @Input() message: string = '';
    @Input() cancelText: string = '';
    @Input() confirmText: string = '';

    @Input() nodel = false;
    @Output() nodelChange = new EventEmitter<boolean>();

    @Output() cancel = new EventEmitter<void>();
    @Output() confirm = new EventEmitter<void>();

    onBackdropClick(): void {
        this.emitCancel();
    }

    onDialogClick(event: MouseEvent): void {
        event.stopPropagation();
    }

    onCancelClick(): void {
        this.emitCancel();
    }

    onConfirmClick(): void {
        this.nodel = false;
        this.nodelChange.emit(this.nodel);
        this.confirm.emit();
    }

    private emitCancel(): void {
        if (this.nodel) {
            this.nodel = false;
            this.nodelChange.emit(this.nodel);
        }
        this.cancel.emit();
    }
}
