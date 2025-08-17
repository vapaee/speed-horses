import { Component, OnDestroy, OnInit } from '@angular/core';
import { Router, RouterOutlet, NavigationEnd } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import { SharedModule } from '@app/shared/shared.module';
import { TabMenu } from 'primeng/tabmenu';
import { MenuItem } from 'primeng/api';
import { filter, Subscription } from 'rxjs';

@Component({
    standalone: true,
    selector: 'app-horses',
    imports: [SharedModule, TabMenu, RouterOutlet],
    template: `
        <p-tabmenu
            class="sh-tabs__bar"
            [model]="items"
            [activeItem]="activeItem"
            (activeItemChange)="onActiveItemChange($event)">
        </p-tabmenu>

        <div class="sh-tabs__content">
            <router-outlet></router-outlet>
        </div>
    `,
    styleUrls: ['./horses.component.scss']
})
export class HorsesPage implements OnInit, OnDestroy {
    // Items with routerLink will navigate automatically
    items: MenuItem[] = [];
    activeItem?: MenuItem;

    private sub?: Subscription;

    constructor(
        private translate: TranslateService,
        private router: Router
    ) {}

    ngOnInit(): void {
        this.buildItems();
        // Keep active tab in sync with current URL (deep-link, back/forward)
        this.sub = this.router.events
            .pipe(filter((e): e is NavigationEnd => e instanceof NavigationEnd))
            .subscribe(() => this.syncActiveFromUrl());
        // Initial sync (first load)
        this.syncActiveFromUrl();

        // Optional: rebuild labels if language changes
        this.translate.onLangChange.subscribe(() => {
            this.buildItems();
            this.syncActiveFromUrl();
        });
    }

    ngOnDestroy(): void {
        if (this.sub) {
            this.sub.unsubscribe();
        }
    }

    onActiveItemChange(item: MenuItem): void {
        // No need to navigate manually; routerLink in item handles it.
        // We only mirror the state locally.
        this.activeItem = item;
    }

    private buildItems(): void {
        // Use translate.instant for static labels of the tab bar
        const forgeLabel = this.translate.instant('PAGES.HORSES.FORGE.NAME');
        const tradingLabel = this.translate.instant('PAGES.HORSES.TRADING.NAME');

        this.items = [
            { label: forgeLabel, icon: 'pi pi-sparkles', routerLink: ['/horses', 'forge'] },
            { label: tradingLabel, icon: 'pi pi-wallet', routerLink: ['/horses', 'trading'] }
        ];
    }

    private syncActiveFromUrl(): void {
        // Expect URLs like /horses/forge or /horses/trading
        const segments = this.router.url.split('/'); // ['', 'horses', 'forge']
        const tab = segments[2] || 'forge';
        const index = tab === 'trading' ? 1 : 0;
        this.activeItem = this.items[index];
    }
}
