import React, { useState, useEffect, useCallback, useRef } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { Edit2, Trash2, Save, Search, Truck, User, FileCheck, ShieldAlert, ChevronDown, ChevronUp } from 'lucide-react';
import { Button } from '../components/ui/Button';

import VehicleForm, { GlassCard } from '../components/masters/VehicleForm';
import VehicleTable from '../components/masters/VehicleTable';

export default function VehicleMaster() {
  const [vehicles, setVehicles] = useState([]);
  const [formData, setFormData] = useState({
    id: null, vehicleNumber: '', type: '6 Wheel (Lorry/Truck)', ladenType: 'Open Body', 
    ownerName: '', ownerPhone: '', ownerPhone2: '', makeModel: '', fitnessExpiry: null, insuranceExpiry: null, npExpiry: null, grossWeight: '', rcStatus: '', rcVerified: false
  });
  const [loading, setLoading] = useState(false);
  const [vahanData, setVahanData] = useState(null);
  const [fetchingRc, setFetchingRc] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');

  const handleSave = useCallback(async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!formData.vehicleNumber) return toast.error("Vehicle Number is required");
    
    setLoading(true);
    try {
      const payloadToSave = {
        ...formData,
        grossWeight: formData.grossWeight ? parseInt(formData.grossWeight) : null,
      };

      if (formData.id) {
        await api.put(`/vehicles/${payloadToSave.id}`, payloadToSave);
        toast.success('Vehicle updated successfully');
      } else {
        const { id, ...dataToCreate } = payloadToSave;
        await api.post('/vehicles', dataToCreate);
        toast.success('Vehicle created successfully');
      }
      setFormData({ 
        id: null, vehicleNumber: '', type: '6 Wheel (Lorry/Truck)', ladenType: 'Open Body',
        ownerName: '', ownerPhone: '', ownerPhone2: '', makeModel: '', fitnessExpiry: null, insuranceExpiry: null, npExpiry: null, grossWeight: '', rcStatus: '', rcVerified: false 
      });
      fetchVehicles(1);
    } catch (err) {
      toast.error('Failed to save record: ' + (err.error || err.message || 'Unknown error'));
    } finally {
      setLoading(false);
    }
  }, [formData]);

  useKeyboardFlow({
    onSave: handleSave
  });

  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [totalRecords, setTotalRecords] = useState(0);
  const desktopObserverRef = useRef(null);
  
  const [debouncedSearch, setDebouncedSearch] = useState('');
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(searchTerm), 400);
    return () => clearTimeout(timer);
  }, [searchTerm]);

  useEffect(() => {
    setPage(1);
    setVehicles([]);
    setHasMore(true);
  }, [debouncedSearch]);

  const fetchVehicles = async (pageNum = page) => {
    try {
      setLoading(true);
      const url = `/vehicles?page=${pageNum}&limit=50&q=${encodeURIComponent(debouncedSearch)}`;
      const res = await api.get(url);
      
      if (res.data) {
         setVehicles(prev => {
            if (pageNum === 1) return res.data;
            const existingIds = new Set(prev.map(p => p.id));
            const newItems = res.data.filter(d => !existingIds.has(d.id));
            return [...prev, ...newItems];
         });
         setHasMore(res.hasMore);
         setTotalRecords(res.total);
      } else {
         setVehicles(res || []); // legacy fallback
         setHasMore(false);
      }
    } catch (err) {
      toast.error('Failed to fetch data.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchVehicles(page);
  }, [page, debouncedSearch]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      entries => {
        const isIntersecting = entries.some(entry => entry.isIntersecting);
        if (isIntersecting && hasMore && !loading) {
          setPage(prev => prev + 1);
        }
      },
      { threshold: 0, rootMargin: '1500px' }
    );
    if (desktopObserverRef.current) observer.observe(desktopObserverRef.current);
    return () => observer.disconnect();
  }, [hasMore, loading]);

  const handleFetchRC = async () => {
    if (!formData.vehicleNumber) {
      toast.error('Please enter a vehicle number first');
      return;
    }
    setFetchingRc(true);
    setVahanData(null);
    try {
      const cleanNo = formData.vehicleNumber.replace(/\s+/g, '');
      const response = await api.post('/fastag/rc', { vehicleNumber: cleanNo });
      
      const vData = response.data;
      setVahanData(vData);
      
      setFormData(prev => ({
        ...prev,
        type: getVehicleTypeFromWheels(vData.rc_no_of_axle, vData.rc_gvw),
        ownerName: vData.rc_owner_name,
        makeModel: vData.rc_maker_model,
        fitnessExpiry: vData.rc_fit_upto ? new Date(vData.rc_fit_upto) : null,
        insuranceExpiry: vData.rc_insurance_upto ? new Date(vData.rc_insurance_upto) : null,
        npExpiry: vData.rc_np_upto ? new Date(vData.rc_np_upto) : null,
        grossWeight: vData.rc_gvw ? parseInt(vData.rc_gvw) : null,
        rcStatus: vData.rc_status,
        rcVerified: true
      }));
      toast.success('RC Details fetched successfully from VAHAN');
    } catch (err) {
      toast.error('Failed to fetch RC details from VAHAN');
    } finally {
      setFetchingRc(false);
    }
  };

  const handleEdit = (vehicle) => {
    setFormData({
      id: vehicle.id,
      vehicleNumber: vehicle.vehicleNumber || '',
      type: vehicle.type || '6 Wheel (Lorry/Truck)',
      ladenType: vehicle.ladenType || 'Open Body',
      ownerName: vehicle.ownerName || '',
      ownerPhone: vehicle.ownerPhone || '',
      ownerPhone2: vehicle.ownerPhone2 || '',
      makeModel: vehicle.makeModel || '',
      fitnessExpiry: vehicle.fitnessExpiry ? new Date(vehicle.fitnessExpiry) : null,
      insuranceExpiry: vehicle.insuranceExpiry ? new Date(vehicle.insuranceExpiry) : null,
      npExpiry: vehicle.npExpiry ? new Date(vehicle.npExpiry) : null,
      grossWeight: vehicle.grossWeight || '',
      rcStatus: vehicle.rcStatus || '',
      rcVerified: vehicle.rcVerified || false
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this record?')) return;
    try {
      await api.delete(`/vehicles/${id}`);
      fetchVehicles(1);
      toast.success('Record deleted');
    } catch (err) {
      toast.error('Failed to delete record');
    }
  };

  const getVehicleTypeFromWheels = (axlesStr, gvwStr) => {
    const axles = parseInt(axlesStr);
    const gvw = parseInt(gvwStr);
    if (!axles) return '6 Wheel (Lorry/Truck)';
    if (axles === 2) return gvw <= 3500 ? '4 Wheel (Van/Minidor)' : '6 Wheel (Lorry/Truck)'; // 6 Wheeler
    if (axles === 3) return '10 Wheel (Taurus)'; // 10 Wheeler
    if (axles === 4) return '12 Wheeler';
    if (axles === 5) return '14 Wheeler';
    if (axles === 6) return '18 Wheeler';
    if (axles === 7) return '22 Wheeler';
    return `${axles * 4 - 6} Wheeler`;
  };

  const filteredVehicles = vehicles.filter(v => 
    (v.vehicleNumber && v.vehicleNumber.toLowerCase().includes(searchTerm.toLowerCase())) || 
    (v.ownerName && v.ownerName.toLowerCase().includes(searchTerm.toLowerCase())) ||
    (v.ownerPhone && v.ownerPhone.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  return (
    <div className="space-y-4 max-w-[1200px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER CARD */}
      <GlassCard className="!p-4">
        <div className="flex items-center gap-3">
          <div className="bg-emerald-50 text-emerald-600 p-2 rounded-xl shadow-inner border border-emerald-100/50">
            <Truck size={20} />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 tracking-tight">Vehicle Master</h2>
            <p className="text-xs font-medium text-slate-500">Manage lorries, vehicle types, and driver details.</p>
          </div>
        </div>
      </GlassCard>

      {/* TOP-DOWN STACKED LAYOUT FOR FORMS */}
      <VehicleForm 
        formData={formData}
        setFormData={setFormData}
        vahanData={vahanData}
        setVahanData={setVahanData}
        fetchingRc={fetchingRc}
        handleFetchRC={handleFetchRC}
        handleSave={handleSave}
        loading={loading}
        getVehicleTypeFromWheels={getVehicleTypeFromWheels}
      />

      {/* LIST CARD */}
      <VehicleTable 
        vehicles={vehicles}
        filteredVehicles={filteredVehicles}
        totalRecords={totalRecords}
        loading={loading}
        hasMore={hasMore}
        searchTerm={searchTerm}
        setSearchTerm={setSearchTerm}
        desktopObserverRef={desktopObserverRef}
        handleEdit={handleEdit}
        handleDelete={handleDelete}
      />
    </div>
  );
}
