import { useQuery } from "@tanstack/react-query";
import { fetchHealth } from "@/api";
import { useRef } from "react";

export function useHealth() {
  const failureCountRef = useRef(0);
  
  const healthQuery = useQuery({
    queryKey: ["health"],
    queryFn: fetchHealth,
    refetchInterval: (query) => {
      // If server is healthy, stop polling
      if (query.state.data === true) {
        failureCountRef.current = 0;
        return false;
      }
      
      // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (max)
      const backoffMs = Math.min(1000 * Math.pow(2, failureCountRef.current), 30000);
      failureCountRef.current++;
      
      return backoffMs;
    },
    refetchIntervalInBackground: true,
    retry: false, // Don't retry, just return false
    staleTime: 0, // Always consider stale so we keep polling
  });

  return {
    isHealthy: healthQuery.data ?? false,
    isChecking: healthQuery.isLoading,
  };
}
