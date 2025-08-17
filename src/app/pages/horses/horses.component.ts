// src/app/pages/horses/horses.component.ts
import { Component, OnDestroy, OnInit } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { TabsModule } from 'primeng/tabs';
import { TradingPage } from '../trading/trading.component';
import { ForgePage } from '../forge/forge.component';
import { ActivatedRoute, Router, NavigationEnd } from '@angular/router';
import { filter, Subscription } from 'rxjs';

@Component({
    standalone: true,
    selector: 'app-horses',
    imports: [
        SharedModule,
        TabsModule,
        TradingPage,
        ForgePage
    ],
    template: `
        <p-tabs
            [value]="activeTab"
            (valueChange)="onTabChange($event)"
            class="sh-tabs"
        >
            <p-tablist>
                <p-tab value="forge">
                    <i class="pi pi-sparkles"></i>
                    <span>{{ 'PAGES.HORSES.FORGE.NAME' | translate }}</span>
                </p-tab>
                <p-tab value="trading">
                    <i class="pi pi-wallet"></i>
                    <span>{{ 'PAGES.HORSES.TRADING.NAME' | translate }}</span>
                </p-tab>
            </p-tablist>

            <p-tabpanels>
                <p-tabpanel value="forge">
                    <app-forge></app-forge>
                </p-tabpanel>
                <p-tabpanel value="trading">
                    <app-trading></app-trading>
                </p-tabpanel>
            </p-tabpanels>
        </p-tabs>
    `,
    styleUrls: ['./horses.component.scss']
})
export class HorsesPage implements OnInit, OnDestroy {
    // active tab id matches the route param (:tab)
    activeTab: 'forge' | 'trading' = 'forge';

    private sub?: Subscription;

    constructor(
        private router: Router,
        private route: ActivatedRoute
    ) {}

    ngOnInit(): void {
        // Initialize from current route and keep in sync on navigation
        this.sub = this.router.events
            .pipe(filter((e): e is NavigationEnd => e instanceof NavigationEnd))
            .subscribe(() => {
                const tab = (this.route.snapshot.paramMap.get('tab') ?? 'forge') as 'forge' | 'trading';
                if (tab !== this.activeTab) {
                    this.activeTab = this.normalizeTab(tab);
                }
            });

        // Also handle first load (in case there is no NavigationEnd yet)
        const initialTab = (this.route.snapshot.paramMap.get('tab') ?? 'forge') as 'forge' | 'trading';
        this.activeTab = this.normalizeTab(initialTab);
    }

    ngOnDestroy(): void {
        if (this.sub) {
            this.sub.unsubscribe();
        }
    }

    onTabChange(next: string | number): void {
        console.log('HorsesPage,onTabChange()', { next });
        // Update URL when user changes tab
        const normalized = this.normalizeTab(next as string);
        if (normalized !== this.activeTab) {
            this.activeTab = normalized;
        }
        this.router.navigate(['/horses', this.activeTab], {
            replaceUrl: true // keep history clean; quítalo si quieres historizar
        });
    }

    private normalizeTab(tab:  string): 'forge' | 'trading' {
        // Fallback to 'forge' for any unknown value
        if (tab === 'trading') {
            return 'trading';
        } else {
            return 'forge';
        }
    }
}
