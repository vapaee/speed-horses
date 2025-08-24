// src/app/shared/shared.module.ts
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import { FormsModule } from '@angular/forms';

@NgModule({
    exports: [
        TranslateModule,
        CommonModule,
        FormsModule,
    ]
})
export class SharedModule {}
