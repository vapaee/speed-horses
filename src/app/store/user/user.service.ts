// src/app/state/paradas/paradas.service.ts
import { Injectable } from '@angular/core';
import { Store } from '@ngrx/store';
import { Observable } from 'rxjs';
import { user } from '.';
import { UserState } from './user.types';


@Injectable({
    providedIn: 'root'
})
export class UserStateService {
    // Selectors
    readonly hue0$: Observable<number> = this.store.select(user.selectors.hue0);
    readonly hue1$: Observable<number> = this.store.select(user.selectors.hue1);
    readonly isDarkTheme$: Observable<boolean> = this.store.select(user.selectors.isDarkTheme);

    constructor(private store: Store<{ paradas: UserState }>) {}

    setDark(): void {
        this.store.dispatch(user.actions.setDark());
    }

    setLight(): void {
        this.store.dispatch(user.actions.setLight());
    }

    setHue0(h0: number): void {
        this.store.dispatch(user.actions.setHue0({ h0 }));
    }

    setHue1(h1: number): void {
        this.store.dispatch(user.actions.setHue1({ h1 }));
    }

    setHueTheme(h0: number, h1: number): void {
        this.store.dispatch(user.actions.setHueTheme({ h0, h1 }));
    }

    toggleTheme(): void {
        this.store.dispatch(user.actions.toggleTheme());
    }

}
