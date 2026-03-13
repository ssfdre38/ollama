/**
 * Standard error handling patterns for the UI
 */

export class APIError extends Error {
  statusCode?: number;
  endpoint?: string;
  
  constructor(
    message: string,
    statusCode?: number,
    endpoint?: string,
  ) {
    super(message);
    this.name = "APIError";
    this.statusCode = statusCode;
    this.endpoint = endpoint;
  }
}

export class NetworkError extends Error {
  constructor(message: string = "Network request failed") {
    super(message);
    this.name = "NetworkError";
  }
}

export class ValidationError extends Error {
  field?: string;
  
  constructor(
    message: string,
    field?: string,
  ) {
    super(message);
    this.name = "ValidationError";
    this.field = field;
  }
}

/**
 * Standardized error handler for API calls
 */
export function handleAPIError(error: unknown, endpoint?: string): APIError | NetworkError {
  if (error instanceof Response) {
    return new APIError(
      `HTTP ${error.status}: ${error.statusText}`,
      error.status,
      endpoint,
    );
  }
  
  if (error instanceof TypeError && error.message.includes("fetch")) {
    return new NetworkError("Failed to connect to server");
  }
  
  if (error instanceof Error) {
    return new APIError(error.message, undefined, endpoint);
  }
  
  return new APIError("An unknown error occurred", undefined, endpoint);
}

/**
 * Check if an error is retryable (5xx or network error)
 */
export function isRetryableError(error: unknown): boolean {
  if (error instanceof APIError && error.statusCode) {
    // Retry on 5xx server errors and 429 rate limit
    return error.statusCode >= 500 || error.statusCode === 429;
  }
  
  if (error instanceof NetworkError) {
    return true; // Network errors are retryable
  }
  
  return false;
}

/**
 * Extract user-friendly error message
 */
export function getErrorMessage(error: unknown): string {
  if (error instanceof APIError) {
    if (error.statusCode === 401) {
      return "Authentication required";
    }
    if (error.statusCode === 403) {
      return "Access denied";
    }
    if (error.statusCode === 404) {
      return "Resource not found";
    }
    if (error.statusCode && error.statusCode >= 500) {
      return "Server error - please try again";
    }
    return error.message;
  }
  
  if (error instanceof NetworkError) {
    return "Connection failed - check your internet connection";
  }
  
  if (error instanceof ValidationError) {
    return error.field ? `${error.field}: ${error.message}` : error.message;
  }
  
  if (error instanceof Error) {
    return error.message;
  }
  
  return "An unexpected error occurred";
}
