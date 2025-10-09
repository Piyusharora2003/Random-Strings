import { Routes } from '@angular/router';
import { authGuard } from './guards/auth.guard';

export const routes: Routes = [
  { path: '', loadComponent: () => import('./main/main.component').then(m => m.MainComponent), canActivate: [authGuard] },
  { path: 'home', loadComponent: () => import('./home/home.component').then(m => m.HomeComponent) },
];
