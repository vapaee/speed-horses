// src/app/app.routes.ts
import { Routes } from '@angular/router';

export const routes: Routes = [
    { path: '', loadComponent: () => import('@app/pages/home/home.component').then(m => m.HomePage) },
    { path: 'fixture', loadComponent: () => import('@app/pages/fixture/fixture.component').then(m => m.FixtureComponent) },
    {
        path: 'horses',
        loadComponent: () => import('@app/pages/horses/horses.component').then(m => m.HorsesPage),
        children: [
            { path: '', pathMatch: 'full', redirectTo: 'forge' },
            { path: 'forge', loadComponent: () => import('@app/pages/forge/forge.component').then(m => m.ForgePage) },
            { path: 'trading', loadComponent: () => import('@app/pages/trading/trading.component').then(m => m.TradingPage) }
        ]
    },
    {
        path: 'shop',
        loadComponent: () => import('@app/pages/shop/shop.component').then(m => m.ShopPage),
        children: [
            { path: '', pathMatch: 'full', redirectTo: 'horseshoes' },
            { path: 'horseshoes', loadComponent: () => import('@app/pages/horseshoes/horseshoes.component').then(m => m.HorseshoesPage) },
            { path: 'accessories', loadComponent: () => import('@app/pages/accessories/accessories.component').then(m => m.AccessoriesPage) },
            { path: 'jockeys', loadComponent: () => import('@app/pages/jockeys/jockeys.component').then(m => m.JockeysPage) }
        ]
    },
    {
        path: 'refuge',
        loadComponent: () => import('@app/pages/refuge/refuge.component').then(m => m.RefugePage),
        children: [
            { path: '', pathMatch: 'full', redirectTo: 'paddock' },
            { path: 'paddock', loadComponent: () => import('@app/pages/paddock/paddock.component').then(m => m.PaddockPage) },
            { path: 'inventory', loadComponent: () => import('@app/pages/inventory/inventory.component').then(m => m.InventoryPage) }
        ]
    }
];
