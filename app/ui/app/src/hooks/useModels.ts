import { useQuery } from "@tanstack/react-query";
import { Model } from "@/gotypes";
import { getModels } from "@/api";
import { mergeModels } from "@/utils/mergeModels";
import { useMemo } from "react";
import { useCloudStatus } from "./useCloudStatus";

export function useModels(searchQuery = "") {
  const { cloudDisabled } = useCloudStatus();
  const localQuery = useQuery<Model[], Error>({
    queryKey: ["models", searchQuery],
    queryFn: () => getModels(searchQuery),
    gcTime: 10 * 60 * 1000, // Keep in cache for 10 minutes
    retry: (failureCount, error) => {
      // Don't retry on 4xx client errors (except 429 rate limit)
      if (error instanceof Error && error.message.includes('4')) {
        const match = error.message.match(/(\d{3})/);
        if (match?.[1]) {
          const status = parseInt(match[1], 10);
          if (status >= 400 && status < 500 && status !== 429) {
            return false; // Don't retry client errors
          }
        }
      }
      // Retry up to 3 times for 5xx server errors and network errors
      return failureCount < 3;
    },
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 5000), // 1s, 2s, 4s
    refetchOnWindowFocus: true,
    refetchInterval: 30 * 1000, // Refetch every 30 seconds to keep models updated
    refetchIntervalInBackground: true,
  });

  const allModels = useMemo(() => {
    const models = mergeModels(localQuery.data || [], cloudDisabled);

    if (searchQuery && searchQuery.trim()) {
      const query = searchQuery.toLowerCase().trim();
      const filteredModels = models.filter((model) =>
        model.model.toLowerCase().includes(query),
      );

      const seen = new Set<string>();
      return filteredModels.filter((model) => {
        const currentModel = model.model.toLowerCase();
        if (seen.has(currentModel)) {
          return false;
        }
        seen.add(currentModel);
        return true;
      });
    }

    return models;
  }, [localQuery.data, searchQuery, cloudDisabled]);

  return {
    ...localQuery,
    data: allModels,
    isLoading: localQuery.isLoading,
  };
}

export function useRefetchModels() {
  const { refetch } = useModels();
  return refetch;
}
