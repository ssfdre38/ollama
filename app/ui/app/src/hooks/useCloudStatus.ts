import { useQuery } from "@tanstack/react-query";
import { getCloudStatus, type CloudStatusResponse } from "@/api";

export function useCloudStatus() {
  const cloudQuery = useQuery<CloudStatusResponse | null>({
    queryKey: ["cloudStatus"],
    queryFn: getCloudStatus,
    retry: 3,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 10000), // 1s, 2s, 4s, max 10s
    staleTime: 5 * 60 * 1000, // 5 minutes (increased from 1 minute)
    gcTime: 10 * 60 * 1000, // Keep in cache for 10 minutes
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
