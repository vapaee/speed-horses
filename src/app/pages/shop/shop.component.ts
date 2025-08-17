import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { TabViewModule } from 'primeng/tabview';

@Component({
    standalone: true,
    selector: 'app-shop',
    imports: [SharedModule, TabViewModule],
    template: `
        <div class="p-shop">
            <p-tabView>
                <p-tabPanel header="{{ 'PAGES.SHOP.SHOES.NAME' | translate }}">
                </p-tabPanel>
                <p-tabPanel header="{{ 'PAGES.SHOP.HORSE.NAME' | translate }}">
                </p-tabPanel>
                <p-tabPanel header="{{ 'PAGES.SHOP.JOCKEY.NAME' | translate }}">
                </p-tabPanel>
            </p-tabView>
        </div>
    `,
    styleUrls: ['./shop.component.scss']
})
export class ShopComponent {}
