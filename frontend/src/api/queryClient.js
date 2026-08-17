import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Data is considered fresh for 1 hour (prevents redundant background fetching)
      staleTime: 60 * 60 * 1000, 
      // Keep data in cache for 2 hours
      gcTime: 120 * 60 * 1000,
      // Refetch on window focus only if stale
      refetchOnWindowFocus: true,
      // Retry failed queries 1 time
      retry: 1,
    },
  },
});
