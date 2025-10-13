import { Component, Input, ViewEncapsulation } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
    standalone: true,
    selector: 'app-section-button',
    imports: [RouterLink],
    templateUrl: './section-button.component.html',
    styleUrls: ['./section-button.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class SectionButtonComponent {
    @Input({ required: true })
    imageSrc!: string;

    @Input({ required: true })
    label!: string;

    @Input()
    link: string | any[] = '';
}
