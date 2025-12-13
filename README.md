New Authentication and Flow:

Authentication Changes: Previously, user preferences were stored locally. Now, user details are stored in a database via the common layer, our API gateway.

Login Flow: When a user logs in, the MFE shell redirects to the common layer’s /token endpoint for session creation. Once validated, the user is redirected back with a session ID.

Headers Used for Authorization and Routing:

menu-name: Indicates which part of the application is calling the API for authorization.

user-info: Carries encrypted user information, acting like a JWT token.

user-pref-region: Specifies the region (e.g., US or EU) for the PPLE backend, so the common layer can route requests accordingly.

Flow of Requests:

Initial User Detail API Call: The MFE shell calls the common layer to get user details.

Routing Subsequent Requests: Any requests to /pple/... endpoints are forwarded by the common layer to the appropriate PPLE backend based on the region header.

Mermaid Diagram:

sequenceDiagram
    participant User
    participant MFE_Shell
    participant Common_Layer
    participant PPLE_Backend

    User->>MFE_Shell: Clicks Login
    MFE_Shell->>Common_Layer: Request userDetail API
    Common_Layer->>Common_Layer: Fetch user details, return to shell
    MFE_Shell->>Common_Layer: Subsequent /pple/... requests
    Common_Layer->>PPLE_Backend: Forward to PPLE backend based on region
    PPLE_Backend-->>Common_Layer: Return response
    Common_Layer-->>MFE_Shell: Forward response to client
