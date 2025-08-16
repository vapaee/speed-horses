import { Routes } from '@angular/router';
import { HomeComponent } from '@app/pages/home/home.component';

export const routes: Routes = [
    // Navigate to 'home' component by default (empty path)
    { path: '', component: HomeComponent },

];
