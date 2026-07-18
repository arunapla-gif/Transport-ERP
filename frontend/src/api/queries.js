import { useQuery } from '@tanstack/react-query';
import { api } from '../api'; // Import generic api wrapper

export const useConsignors = () => {
  return useQuery({
    queryKey: ['consignors'],
    queryFn: () => api.get('/consignors'),
  });
};

export const useConsignees = () => {
  return useQuery({
    queryKey: ['consignees'],
    queryFn: () => api.get('/consignees'),
  });
};

export const useVehicles = () => {
  return useQuery({
    queryKey: ['vehicles'],
    queryFn: () => api.get('/vehicles'),
  });
};

export const useGodowns = () => {
  return useQuery({
    queryKey: ['godowns'],
    queryFn: () => api.get('/godowns'),
  });
};

export const useDrivers = () => {
  return useQuery({
    queryKey: ['drivers'],
    queryFn: () => api.get('/drivers'),
  });
};

export const useUnits = () => {
  return useQuery({
    queryKey: ['units'],
    queryFn: () => api.get('/units'),
  });
};

// DO NOT ADD ewaybill OR driving license fetch here. 
// They must always remain uncached live fetches!
