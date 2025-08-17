import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { TabViewModule } from 'primeng/tabview';

@Component({
    standalone: true,
    selector: 'app-refuge',
    imports: [SharedModule, TabViewModule],
    template: `
        <div class="p-refuge">
            <p-tabView>
                <p-tabPanel header="{{ 'PAGES.REFUGE.PADDOCK.NAME' | translate }}">
                </p-tabPanel>
                <p-tabPanel header="{{ 'PAGES.REFUGE.INVENTORY.NAME' | translate }}">
                </p-tabPanel>
            </p-tabView>
        </div>
    `,
    styleUrls: ['./refuge.component.scss']
})
export class RefugePage {}
