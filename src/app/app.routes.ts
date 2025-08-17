// src/app/app.routes.ts
import { Routes } from '@angular/router';
import { HomePage } from '@app/pages/home/home.component';
import { FixtureComponent } from '@app/pages/fixture/fixture.component';
import { HorsesPage } from '@app/pages/horses/horses.component';
import { ShopPage } from '@app/pages/shop/shop.component';
import { RefugePage } from '@app/pages/refuge/refuge.component';

export const routes: Routes = [
    { path: '', component: HomePage },
    { path: 'fixture', component: FixtureComponent },
    { path: 'horses', pathMatch: 'full', redirectTo: 'horses/forge' },
    { path: 'horses/:tab', component: HorsesPage },
    { path: 'shop', component: ShopPage },
    { path: 'refuge', component: RefugePage },
];
