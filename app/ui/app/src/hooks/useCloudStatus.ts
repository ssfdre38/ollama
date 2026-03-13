import { useQuery } from "@tanstack/react-query";
import { getCloudStatus, type CloudStatusResponse } from "@/api";

export function useCloudStatus() {
  const cloudQuery = useQuery<CloudStatusResponse | null>({
    queryKey: ["cloudStatus"],
    queryFn: getCloudStatus,
    retry: 3, // Changed: Retry 3 times instead of giving up immediately
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000), // Exponential backoff: 1s, 2s, 4s, max 10s
    staleTime: 60 * 1000,
  });

  return {
    cloudStatus: cloudQuery.data,
    cloudDisabled: cloudQuery.data?.disabled ?? false,
    isKnown: cloudQuery.data !== null && cloudQuery.data !== undefined,
    isLoading: cloudQuery.isLoading,
    isError: cloudQuery.isError,
    error: cloudQuery.error,
  };
}
