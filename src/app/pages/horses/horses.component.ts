import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { TabViewModule } from 'primeng/tabview';

@Component({
    standalone: true,
    selector: 'app-horses',
    imports: [SharedModule, TabViewModule],
    template: `
        <div class="p-horses">
            <p-tabView>
                <p-tabPanel header="{{ 'PAGES.HORSES.FORGE.NAME' | translate }}">
                </p-tabPanel>
                <p-tabPanel header="{{ 'PAGES.HORSES.TRADING.NAME' | translate }}">
                </p-tabPanel>
            </p-tabView>
        </div>
    `,
    styleUrls: ['./horses.component.scss']
})
export class HorsesComponent {}
