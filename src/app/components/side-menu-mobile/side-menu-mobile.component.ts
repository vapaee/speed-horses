import { Component, ViewEncapsulation } from '@angular/core';
import { SideContainerComponent } from '@app/components/base-components/side-container/side-container.component';
import { LucideAngularModule, Calendar, Horse, ShoppingBag, Home } from 'lucide-angular';
import { RouterModule } from '@angular/router';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    selector: 'app-side-menu-mobile',
    imports: [
        SideContainerComponent,
        LucideAngularModule,
        RouterModule,
        SharedModule
    ],
    templateUrl: './side-menu-mobile.component.html',
    styleUrl: './side-menu-mobile.component.scss',
    encapsulation: ViewEncapsulation.None
})
export class SideMenuMobileComponent {
    readonly CalendarIcon = Calendar;
    readonly HorseIcon = Horse;
    readonly ShoppingBagIcon = ShoppingBag;
    readonly HomeIcon = Home;
}
