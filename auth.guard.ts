import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { tap, map } from 'rxjs/operators';
import { of } from 'rxjs';

export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  // If we're still fetching user/token, wait until it's done
  if (authService.loading()) {
    return authService.isLoaded$.pipe(
      map(() => {
        return authService.isAuthenticated() ? true : router.createUrlTree(['/home']);
      })
    );
  }

  // If already loaded, proceed immediately
  if (authService.isAuthenticated()) {
    return true;
  }

  // Not logged in — redirect to home (or login)
  return of(router.createUrlTree(['/home']));
};
