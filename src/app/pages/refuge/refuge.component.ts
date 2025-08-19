import { Component, OnDestroy, OnInit, ViewEncapsulation } from '@angular/core';
import { Router, RouterOutlet, NavigationEnd } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import { SharedModule } from '@app/shared/shared.module';
import { TabMenu } from 'primeng/tabmenu';
import { MenuItem } from 'primeng/api';
import { filter, Subscription } from 'rxjs';

@Component({
    standalone: true,
    selector: 'app-refuge',
    imports: [SharedModule, TabMenu, RouterOutlet],
    template: `
        <p-tabmenu
            class="p-refuge__tabs"
            [model]="items"
            [activeItem]="activeItem"
            (activeItemChange)="onActiveItemChange($event)">
        </p-tabmenu>

        <div class="p-refuge__tabs-content">
            <router-outlet></router-outlet>
        </div>
    `,
    styleUrls: ['./refuge.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class RefugePage implements OnInit, OnDestroy {
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
        const paddockLabel = this.translate.instant('PAGES.REFUGE.PADDOCK.NAME');
        const inventoryLabel = this.translate.instant('PAGES.REFUGE.INVENTORY.NAME');

        this.items = [
            { label: paddockLabel, icon: 'pi pi-home', routerLink: ['/refuge', 'paddock'] },
            { label: inventoryLabel, icon: 'pi pi-briefcase', routerLink: ['/refuge', 'inventory'] }
        ];
    }

    private syncActiveFromUrl(): void {
        const segments = this.router.url.split('/');
        const tab = segments[2] || 'paddock';
        const index = tab === 'inventory' ? 1 : 0;
        this.activeItem = this.items[index];
    }
}
