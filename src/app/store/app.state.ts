// src/app/core/store/app.state.ts

import { ActionReducerMap } from '@ngrx/store';
import { userReducer } from './user/user.reducer';
import { UserEffects } from './user/user.effects';
import { UserState } from './user/user.types';

export interface AppState {
    user: UserState;
}

export const AppEffects = [
    UserEffects,
];

export const AppReducers: ActionReducerMap<AppState> = {
    user: userReducer,
};
