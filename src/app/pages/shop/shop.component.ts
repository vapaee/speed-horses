import { Component, ViewEncapsulation } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { NgIf } from '@angular/common';
import { SharedModule } from '@app/shared/shared.module';
import { SectionButtonComponent } from '@app/components/section-button/section-button.component';

@Component({
    standalone: true,
    selector: 'app-shop',
    imports: [SharedModule, RouterOutlet, NgIf, SectionButtonComponent],
    templateUrl: './shop.component.html',
    styleUrls: ['./shop.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class ShopPage {}
