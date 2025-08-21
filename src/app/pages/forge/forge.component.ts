// src/app/pages/home/home.component.ts
import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-forge',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-forge">
            <span class="p-forge__title">Forge</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./forge.component.scss']
})
export class ForgePage {

}
