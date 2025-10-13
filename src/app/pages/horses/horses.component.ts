import { Component, ViewEncapsulation } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { NgIf } from '@angular/common';
import { SharedModule } from '@app/shared/shared.module';
import { SectionButtonComponent } from '@app/components/section-button/section-button.component';

@Component({
    standalone: true,
    selector: 'app-horses',
    imports: [SharedModule, RouterOutlet, NgIf, SectionButtonComponent],
    templateUrl: './horses.component.html',
    styleUrls: ['./horses.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class HorsesPage {}
