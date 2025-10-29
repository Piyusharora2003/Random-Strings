apicall(
  rel_url: string,
  type: string,
  body?: any,
  option?: any,
  use_base = true
): Observable<any> {
  const isLoginUrl =
    rel_url.includes('CHECK_LOGIN') || rel_url.includes('user/userDetail');

  // 🚧 If token missing & not a login endpoint, hold the call until ready
  if (!this.userToken && !isLoginUrl) {
    return this.tokenReady$.pipe(
      filter((ready) => ready),
      take(1),
      switchMap(() => this.apicall(rel_url, type, body, option, use_base))
    );
  }

  // ✅ Build request headers (skip User-Info if login URL)
  const headersConfig: any = {
    'Content-Type': 'application/json',
    Region: this.selectedRegion,
    'Content-Encoding': 'gzip',
    'Menu-Name': this.menuMapService.getActiveMenuName(),
  };

  if (!isLoginUrl && this.userToken) {
    headersConfig['User-Info'] = this.userToken;
  }

  const headers = new HttpHeaders(headersConfig);

  // ✅ Base URL logic
  let url = rel_url;
  if (use_base) {
    if (
      environment['AUTHORIZATION_BEARER'] === 'IMS' ||
      rel_url === urls['CHECK_LOGIN']
    ) {
      url = rel_url === urls['CHECK_LOGIN']
        ? `${this.base_url_admin}/user/userDetail`
        : `${this.base_url}${rel_url}`;
    } else {
      url = `${this.base_url}pple/${rel_url}`;
    }
  }

  this.increase_requests();
  this.request_in_progress = true;

  // ✅ Prepare HTTP call
  let request$: Observable<any> | null = null;
  switch (type) {
    case 'GET':
      request$ = this.client.get(url, { headers, params: option, withCredentials: true });
      break;
    case 'POST':
      request$ = this.client.post(url, body, { headers, params: option, withCredentials: true });
      break;
    case 'PUT':
      request$ = this.client.put(url, body, { headers, params: option, withCredentials: true });
      break;
    case 'DELETE':
      request$ = this.client.delete(url, { headers, params: option, withCredentials: true });
      break;
  }

  if (!request$) throw new Error(`Unsupported request type: ${type}`);

  // ✅ Shared observable for multiple subscribers
  const result$ = request$.pipe(
    finalize(() => (this.request_in_progress = false)),
    share()
  );

  return result$;
}



private tokenReady$ = new BehaviorSubject<boolean>(false);
userToken: string | null = null;

this.apicallsService.userToken = response.token;
this.apicallsService.tokenReady$.next(true);


return this.tokenReady$.pipe(
  filter((ready) => ready),
  take(1),
  timeout(10000), // wait max 10 seconds
  catchError(() => throwError(() => new Error('Token not ready in time'))),
  switchMap(() => this.apicall(rel_url, type, body, option, use_base))
);




