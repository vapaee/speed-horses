import { Component, OnDestroy, OnInit, ViewEncapsulation } from '@angular/core';
import { Router, RouterOutlet, NavigationEnd } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import { SharedModule } from '@app/shared/shared.module';
import { TabMenu } from 'primeng/tabmenu';
import { MenuItem } from 'primeng/api';
import { filter, Subscription } from 'rxjs';

@Component({
    standalone: true,
    selector: 'app-shop',
    imports: [SharedModule, TabMenu, RouterOutlet],
    template: `
        <p-tabmenu
            class="p-shop__tabs"
            [model]="items"
            [activeItem]="activeItem"
            (activeItemChange)="onActiveItemChange($event)">
        </p-tabmenu>

        <div class="p-shop__tabs-content">
            <router-outlet></router-outlet>
        </div>
    `,
    styleUrls: ['./shop.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class ShopPage implements OnInit, OnDestroy {
    items: MenuItem[] = [];
    activeItem?: MenuItem;
    private sub?: Subscription;

    constructor(
        private translate: TranslateService,
        private router: Router
    ) {}

    ngOnInit(): void {
        this.buildItems();
        this.sub = this.router.events
            .pipe(filter((e): e is NavigationEnd => e instanceof NavigationEnd))
            .subscribe(() => this.syncActiveFromUrl());
        this.syncActiveFromUrl();
        this.translate.onLangChange.subscribe(() => {
            this.buildItems();
            this.syncActiveFromUrl();
        });
    }

    ngOnDestroy(): void {
        this.sub?.unsubscribe();
    }

    onActiveItemChange(item: MenuItem): void {
        this.activeItem = item;
    }

    private buildItems(): void {
        const shoesLabel = this.translate.instant('PAGES.SHOP.SHOES.NAME');
        const accessoriesLabel = this.translate.instant('PAGES.SHOP.ACCESSORIES.NAME');
        const jockeyLabel = this.translate.instant('PAGES.SHOP.JOCKEYS.NAME');

        this.items = [
            { label: shoesLabel, icon: 'pi pi-briefcase', routerLink: ['/shop', 'horseshoes'] },
            { label: accessoriesLabel, icon: 'pi pi-star', routerLink: ['/shop', 'accessories'] },
            { label: jockeyLabel, icon: 'pi pi-user', routerLink: ['/shop', 'jockeys'] }
        ];
    }

    private syncActiveFromUrl(): void {
        const segments = this.router.url.split('/');
        const tab = segments[2] || 'horseshoes';
        let index = 0;
        if (tab === 'accessories') index = 1;
        else if (tab === 'jockeys') index = 2;
        this.activeItem = this.items[index];
    }
}
