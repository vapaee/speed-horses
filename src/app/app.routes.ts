import { Routes } from '@angular/router';
import { HomeComponent } from '@app/pages/home/home.component';
import { FixtureComponent } from '@app/pages/fixture/fixture.component';
import { HorsesComponent } from '@app/pages/horses/horses.component';
import { ShopComponent } from '@app/pages/shop/shop.component';
import { RefugeComponent } from '@app/pages/refuge/refuge.component';

export const routes: Routes = [
    { path: '', component: HomeComponent },
    { path: 'fixture', component: FixtureComponent },
    { path: 'horses', component: HorsesComponent },
    { path: 'shop', component: ShopComponent },
    { path: 'refuge', component: RefugeComponent },
];
