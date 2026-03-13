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
    retry: 3, // Changed: Reduced from 10 to 3 retries (faster failure feedback)
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 5000), // Changed: 1s, 2s, 4s (instead of 100ms start)
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
