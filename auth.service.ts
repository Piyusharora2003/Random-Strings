import { Injectable, signal } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private _isAuthenticated = signal(false);
  private _loading = signal(true);
  isLoaded$ = new BehaviorSubject(false);

  constructor() {
    this.initializeAuth();
  }

  private initializeAuth() {
    const token = localStorage.getItem('token');

    if (!token) {
      this._isAuthenticated.set(false);
      this._loading.set(false);
      this.isLoaded$.next(true);
      return;
    }

    // Simulate async user fetch (like hitting /me endpoint)
    setTimeout(() => {
      this._isAuthenticated.set(true);
      this._loading.set(false);
      this.isLoaded$.next(true);
    }, 500);
  }

  isAuthenticated() {
    return this._isAuthenticated();
  }

  loading() {
    return this._loading();
  }

  login(token: string) {
    localStorage.setItem('token', token);
    this._isAuthenticated.set(true);
  }

  logout() {
    localStorage.removeItem('token');
    this._isAuthenticated.set(false);
  }
}
