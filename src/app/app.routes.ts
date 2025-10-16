// src/app/app.routes.ts
import { Routes } from '@angular/router';

export const routes: Routes = [
    { path: '', loadComponent: () => import('@app/pages/home/home.component').then(m => m.HomePage) },
    { path: 'fixture', loadComponent: () => import('@app/pages/fixture/fixture.component').then(m => m.FixtureComponent) },
    {
        path: 'horses',
        loadComponent: () => import('@app/pages/horses/horses.component').then(m => m.HorsesPage),
        children: [
            { path: 'forge', loadComponent: () => import('@app/pages/forge/forge.component').then(m => m.ForgePage) },
            { path: 'trading', loadComponent: () => import('@app/pages/trading/trading.component').then(m => m.TradingPage) }
        ]
    },
    {
        path: 'shop',
        loadComponent: () => import('@app/pages/shop/shop.component').then(m => m.ShopPage),
        children: [
            { path: 'horseshoes', loadComponent: () => import('@app/pages/horseshoes/horseshoes.component').then(m => m.HorseshoesPage) },
            { path: 'accessories', loadComponent: () => import('@app/pages/accessories/accessories.component').then(m => m.AccessoriesPage) },
            { path: 'jockeys', loadComponent: () => import('@app/pages/jockeys/jockeys.component').then(m => m.JockeysPage) }
        ]
    },
    {
        path: 'refuge',
        loadComponent: () => import('@app/pages/refuge/refuge.component').then(m => m.RefugePage),
        children: [
            { path: 'merge', loadComponent: () => import('@app/pages/merge/merge.component').then(m => m.MergePage) },
            { path: 'repare', loadComponent: () => import('@app/pages/repare/repare.component').then(m => m.ReparePage) },
            { path: 'ring', loadComponent: () => import('@app/pages/ring/ring.component').then(m => m.RingPage) },
            { path: 'inventory', loadComponent: () => import('@app/pages/inventory/inventory.component').then(m => m.InventoryPage) }
        ]
    }
];
