import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, ReplaySubject, throwError, of } from 'rxjs';
import { tap, shareReplay, switchMap, share } from 'rxjs/operators';

@Injectable({
  providedIn: 'root'
})
export class ApiCallService {

  // This is your "semaphore".
  // null = "not sent"
  // Observable = "in progress" or "completed"
  private userDetailsCache$: Observable<any> | null = null;
  
  // --- TODO: Define your userDetails endpoint URL ---
  private readonly USER_DETAILS_URL = '/api/v1/userDetails'; 

  constructor(private httpClient: HttpClient) { }

  /**
   * This private function is the "semaphore" logic.
   * It ensures the userDetails call runs only once.
   */
  private getOrFetchUserDetails(): Observable<any> {
    // "Not sent": Create the request, make it "in progress"
    if (!this.userDetailsCache$) {
      this.userDetailsCache$ = this.httpClient.get(this.USER_DETAILS_URL).pipe(
        tap(userInfo => {
          // --- TODO: Store your token here ---
          // Example: localStorage.setItem('auth_token', userInfo.token);
        }),
        // shareReplay(1) is the magic:
        // 1. It multicasts the result to all subscribers.
        // 2. It caches the last (1) emission.
        // 3. Any new subscriber gets the cached value instantly.
        shareReplay(1)
      );
    }
    
    // "In progress" or "Completed": Return the observable
    return this.userDetailsCache$;
  }

  /**
   * Your modified function.
   */
  public apicall(params: any): Observable<any> {
    
    // --- TODO: Your existing logic to parse params ---
    const { method, url, body, options } = this.buildRequestFromParams(params);

    // --- Prevent recursive loop ---
    // If the call *is* for userDetails, just return the semaphore.
    if (url === this.USER_DETAILS_URL) {
      return this.getOrFetchUserDetails().pipe(share());
    }

    // --- All other calls ---
    // 1. Get the semaphore. This will either:
    //    a) Trigger the userDetails call (if "not sent")
    //    b) Wait for the in-progress call
    //    c) Get the cached result instantly
    // 
    // 2. Use switchMap to wait ("hold") until the semaphore emits.
    //
    // 3. Once it emits, proceed ("unlocked") to the actual HTTP request.
    return this.getOrFetchUserDetails().pipe(
      switchMap(userInfo => {
        // Token is now guaranteed to be stored.
        // Make the real request.
        return this.createHttpRequest(method, url, body, options);
      }),
      share() // Keep your original share()
    );
  }

  // --- Helper to create the actual request ---
  private createHttpRequest(method: string, url: string, body?: any, options?: any): Observable<any> {
    switch (method.toLowerCase()) {
      case 'get':
        return this.httpClient.get(url, options);
      case 'post':
        return this.httpClient.post(url, body, options);
      case 'put':
        return this.httpClient.put(url, body, options);
      case 'delete':
        return this.httpClient.delete(url, options);
      default:
        return throwError(() => new Error('Invalid HTTP method'));
    }
  }

  // --- TODO: Replace with your actual helper function ---
  private buildRequestFromParams(params: any): { method: string, url: string, body?: any, options?: any } {
    // Example placeholder
    return { 
      method: params.method || 'get', 
      url: params.url, 
      body: params.body, 
      options: params.options 
    };
  }
}
