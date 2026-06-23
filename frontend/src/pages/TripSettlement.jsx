import React, { useState, useEffect, useMemo } from 'react';
import { api } from '../api';
import { Truck, CheckCircle, Calculator, Building2, User, Coins, Navigation } from 'lucide-react';
import { SearchableSelect } from '../components/ui/SearchableSelect';
import { TrackingModal } from '../components/ui/TrackingModal';

export default function TripSettlement() {
  const [activeTrips, setActiveTrips] = useState([]);
  const [unassignedGdms, setUnassignedGdms] = useState([]);
  
  const [selectedTripId, setSelectedTripId] = useState('');
  const [selectedGdmIds, setSelectedGdmIds] = useState([]);
  
  // State to track allocation per Consignee: { consigneeId: { paidToDriver: 0, paidToTransport: 0 } }
  const [allocations, setAllocations] = useState({});
  const [expandedGroups, setExpandedGroups] = useState({});

  // Tracking Modal State
  const [isTrackingModalOpen, setIsTrackingModalOpen] = useState(false);
  const [trackingVehicleNumber, setTrackingVehicleNumber] = useState('');

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [tripsRes, gdmsRes] = await Promise.all([
        api.get('/trips'),
        api.get('/gdms-unassigned')
      ]);
      const trips = Array.isArray(tripsRes) ? tripsRes : [];
      setActiveTrips(trips.filter(t => t.status === 'Active'));
      setUnassignedGdms(Array.isArray(gdmsRes) ? gdmsRes : []);
    } catch (err) {
      setError('Failed to load settlement data');
    }
  };

  const selectedTrip = activeTrips.find(t => t.id === parseInt(selectedTripId));
  const tripOptions = activeTrips.map(t => ({ 
    value: t.id, 
    label: `${t.tripNumber} (${t.vehicle?.vehicleNumber || 'Unknown'}) - Bal: ₹${t.balanceAmount}` 
  }));

  // Filter GDMs for the selected vehicle
  const gdmsForVehicle = selectedTrip ? unassignedGdms.filter(g => g.vehicleId === selectedTrip.vehicleId) : [];

  // Get all GCs from the selected GDMs
  const activeGcs = useMemo(() => {
    const selectedGdms = gdmsForVehicle.filter(g => selectedGdmIds.includes(g.id));
    let gcs = [];
    selectedGdms.forEach(gdm => {
      if (gdm.gcs) gcs = [...gcs, ...gdm.gcs];
    });
    // Filter only To Pay or GCs with freight
    return gcs;
  }, [selectedGdmIds, gdmsForVehicle]);

  // Group GCs by Consignee
  const consigneeGroups = useMemo(() => {
    const groups = {};
    activeGcs.forEach(gc => {
      const cId = gc.consignee?.id || 'unknown';
      if (!groups[cId]) {
        groups[cId] = {
          consigneeId: cId,
          name: gc.consignee?.name || 'Unknown / Retail Party',
          totalFreightDue: 0,
          gcs: []
        };
      }
      groups[cId].totalFreightDue += (parseFloat(gc.freightTotal) || 0);
      groups[cId].gcs.push(gc);
    });
    return Object.values(groups);
  }, [activeGcs]);

  // Handle checking a GDM
  const toggleGdm = (gdmId) => {
    setSelectedGdmIds(prev => 
      prev.includes(gdmId) ? prev.filter(id => id !== gdmId) : [...prev, gdmId]
    );
  };

  // Handle allocation inputs per Consignee
  const handleAllocationChange = (cId, field, value) => {
    const val = parseFloat(value) || 0;
    setAllocations(prev => ({
      ...prev,
      [cId]: {
        ...prev[cId],
        [field]: val
      }
    }));
  };

  // Quick action: Fill full freight to driver for a Consignee
  const handleFullToDriver = (cId, totalFreightDue) => {
    setAllocations(prev => ({
      ...prev,
      [cId]: { paidToDriver: parseFloat(totalFreightDue) || 0, paidToTransport: 0 }
    }));
  };

  // Calculations
  const tripBalance = selectedTrip?.balanceAmount || 0;
  const totalPaidToDriver = Object.values(allocations).reduce((sum, alloc) => sum + (alloc.paidToDriver || 0), 0);
  const totalPaidToUs = Object.values(allocations).reduce((sum, alloc) => sum + (alloc.paidToTransport || 0), 0);
  
  const difference = totalPaidToDriver - tripBalance;
  const isCrossing = difference > 0;
  const isReturn = difference < 0;
  const absoluteDifference = Math.abs(difference);

  const handleSettleTrip = async () => {
    if (!selectedTripId) return setError('Please select a trip');
    if (selectedGdmIds.length === 0) return setError('Please select at least one GDM');

    try {
      setLoading(true);
      setError('');
      
      // Distribute Consignee allocations across their individual GCs
      const gcAllocations = [];
      Object.entries(allocations).forEach(([cId, alloc]) => {
        const group = consigneeGroups.find(g => g.consigneeId.toString() === cId);
        if (!group) return;
        
        let remainingToDriver = alloc.paidToDriver || 0;
        let remainingToTransport = alloc.paidToTransport || 0;
        
        group.gcs.forEach(gc => {
          const freight = parseFloat(gc.freightTotal) || 0;
          
          const toDriver = Math.min(freight, remainingToDriver);
          remainingToDriver -= toDriver;
          
          const remainingFreight = freight - toDriver;
          const toTransport = Math.min(remainingFreight, remainingToTransport);
          remainingToTransport -= toTransport;
          
          gcAllocations.push({
            gcId: gc.id,
            paidToDriver: toDriver,
            paidToTransport: toTransport
          });
        });
      });

      const payload = {
        gdmIds: selectedGdmIds,
        allocations: gcAllocations,
        crossingAmount: isCrossing ? absoluteDifference : 0,
        returnAmount: isReturn ? absoluteDifference : 0
      };

      await api.post(`/trips/${selectedTripId}/settle`, payload);
      setSuccess(`Trip Settled successfully!`);
      
      // Reset form
      setSelectedTripId('');
      setSelectedGdmIds([]);
      setAllocations({});
      fetchData(); // Refresh active trips and GDMs

      setTimeout(() => setSuccess(''), 4000);
    } catch (err) {
      setError(err.message || 'Failed to settle Trip');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-6 pb-10 pt-4" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      <div className="flex items-center gap-3 mb-8">
        <div className="bg-fuchsia-100 text-fuchsia-700 p-2.5 rounded-xl shadow-sm">
          <Calculator size={24} />
        </div>
        <div>
          <h1 className="text-2xl font-black text-slate-800 tracking-tight">Trip Settlement</h1>
          <p className="text-sm font-medium text-slate-500">Allocate consignee payments and calculate final Crossing or Return.</p>
        </div>
      </div>

      {error && <div className="bg-rose-50 text-rose-600 p-4 rounded-xl text-sm font-bold border border-rose-200">{error}</div>}
      {success && <div className="bg-emerald-50 text-emerald-600 p-4 rounded-xl text-sm font-bold border border-emerald-200 flex items-center gap-2"><CheckCircle size={16}/> {success}</div>}

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Trip & GDM Selection */}
        <div className="lg:col-span-4 space-y-6">
          <div className="bg-white/80 backdrop-blur-xl border border-slate-200/60 rounded-2xl p-5 shadow-sm">
            <h2 className="text-lg font-black text-slate-800 mb-4 flex items-center gap-2">
              <span className="w-6 h-6 rounded-md bg-slate-100 text-slate-600 flex items-center justify-center text-xs">1</span> 
              Select Active Trip
            </h2>
            <SearchableSelect 
               label="Active Trips"
               options={tripOptions}
               value={selectedTripId}
               onChange={(val) => {
                 setSelectedTripId(val);
                 setSelectedGdmIds([]); // Reset selected GDMs when trip changes
                 setAllocations({});
               }}
               placeholder="Search Trip..."
             />

             {selectedTrip && (
               <div className="mt-5 p-4 bg-slate-50 rounded-xl border border-slate-200 space-y-2">
                 <div className="flex justify-between items-center text-sm">
                   <span className="text-slate-500 font-bold">Vehicle:</span>
                   <div className="flex items-center gap-2">
                     <span className="text-slate-800 font-black">{selectedTrip.vehicle?.vehicleNumber}</span>
                     <button
                        onClick={() => {
                          setTrackingVehicleNumber(selectedTrip.vehicle?.vehicleNumber);
                          setIsTrackingModalOpen(true);
                        }}
                        className="p-1.5 bg-blue-50 hover:bg-blue-100 text-blue-600 rounded-lg transition-colors"
                        title="Track Lorry Location"
                     >
                        <Navigation size={14} />
                     </button>
                   </div>
                 </div>
                 <div className="flex justify-between items-center text-sm">
                   <span className="text-slate-500 font-bold">Lorry Hire:</span>
                   <span className="text-slate-800 font-black">₹ {selectedTrip.lorryHire}</span>
                 </div>
                 <div className="flex justify-between items-center text-sm">
                   <span className="text-slate-500 font-bold">Advance Paid:</span>
                   <span className="text-emerald-600 font-black">₹ {selectedTrip.advancePaid}</span>
                 </div>
                 <div className="pt-2 mt-2 border-t border-slate-200 flex justify-between items-center">
                   <span className="text-indigo-600 font-bold">Trip Balance:</span>
                   <span className="text-indigo-700 font-black text-lg">₹ {tripBalance.toFixed(2)}</span>
                 </div>
               </div>
             )}
          </div>

          {selectedTrip && (
            <div className="bg-white/80 backdrop-blur-xl border border-slate-200/60 rounded-2xl p-5 shadow-sm">
              <h2 className="text-lg font-black text-slate-800 mb-4 flex items-center gap-2">
                <span className="w-6 h-6 rounded-md bg-slate-100 text-slate-600 flex items-center justify-center text-xs">2</span> 
                Attach GDMs
              </h2>
              {gdmsForVehicle.length === 0 ? (
                <p className="text-sm font-bold text-rose-500 bg-rose-50 p-3 rounded-lg">No unassigned GDMs found for this vehicle.</p>
              ) : (
                <div className="space-y-3 max-h-64 overflow-y-auto pr-2">
                  {gdmsForVehicle.map(gdm => (
                    <label key={gdm.id} className={`flex items-center gap-3 p-3 rounded-xl border-2 cursor-pointer transition-colors ${selectedGdmIds.includes(gdm.id) ? 'border-fuchsia-500 bg-fuchsia-50/50' : 'border-slate-200 hover:border-slate-300'}`}>
                      <input 
                        type="checkbox" 
                        className="w-5 h-5 rounded text-fuchsia-600 border-slate-300 focus:ring-fuchsia-500"
                        checked={selectedGdmIds.includes(gdm.id)}
                        onChange={() => toggleGdm(gdm.id)}
                      />
                      <div className="flex-1">
                        <div className="font-black text-slate-800">{gdm.gdmNumber}</div>
                        <div className="text-xs font-bold text-slate-500">{gdm.gcs?.length || 0} GCs Attached</div>
                      </div>
                    </label>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Right Column: Allocation Engine & Settlement */}
        <div className="lg:col-span-8 space-y-6">
           <div className={`bg-white/80 backdrop-blur-xl border ${selectedTrip && selectedGdmIds.length > 0 ? 'border-fuchsia-200 shadow-fuchsia-900/5' : 'border-slate-200/60'} rounded-2xl p-6 shadow-sm min-h-[500px] flex flex-col`}>
              <h2 className="text-lg font-black text-slate-800 mb-6 flex items-center gap-2">
                <span className="w-6 h-6 rounded-md bg-slate-100 text-slate-600 flex items-center justify-center text-xs">3</span> 
                Consignee Allocation Engine
              </h2>

              {(!selectedTrip || selectedGdmIds.length === 0) ? (
                <div className="flex-1 flex flex-col items-center justify-center text-slate-400">
                  <User size={48} className="mb-3 opacity-20" />
                  <p className="font-medium text-sm">Select a Trip and attach GDMs to begin allocation</p>
                </div>
              ) : (
                <div className="flex-1 flex flex-col">
                   <div className="space-y-4 mb-8 flex-1">
                     {consigneeGroups.map(group => {
                       const alloc = allocations[group.consigneeId] || { paidToDriver: 0, paidToTransport: 0 };
                       const isExpanded = expandedGroups[group.consigneeId];
                       
                       return (
                         <div key={group.consigneeId} className="bg-white border border-slate-200 rounded-xl shadow-sm relative overflow-hidden transition-all">
                           <div className="absolute top-0 left-0 w-1 h-full bg-fuchsia-500" />
                           <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-4 pl-5">
                             {/* Consignee Details */}
                             <div className="flex-1 cursor-pointer" onClick={() => setExpandedGroups(prev => ({...prev, [group.consigneeId]: !isExpanded}))}>
                               <div className="flex items-center gap-1.5 text-lg font-black text-slate-800 mb-1">
                                 <Building2 size={16} className="text-fuchsia-600" />
                                 {group.name}
                               </div>
                               <div className="flex items-center gap-2">
                                 <span className="flex items-center gap-1 text-xs font-bold text-slate-500 bg-slate-100 hover:bg-slate-200 transition-colors px-2 py-0.5 rounded-md cursor-pointer">
                                   {group.gcs.length} GC{group.gcs.length > 1 ? 's' : ''} Linked
                                   <svg className={`w-3 h-3 transform transition-transform ${isExpanded ? 'rotate-180' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" /></svg>
                                 </span>
                               </div>
                             </div>

                             {/* Total Owed */}
                             <div className="bg-slate-50 px-5 py-2.5 rounded-xl text-center min-w-[120px] border border-slate-100">
                               <div className="text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-0.5">Total Due</div>
                               <div className="font-black text-slate-800 text-xl">₹{group.totalFreightDue.toFixed(2)}</div>
                             </div>

                             {/* Allocation Inputs */}
                             <div className="flex items-center gap-3 bg-fuchsia-50/30 p-2.5 rounded-xl border border-fuchsia-100/50">
                               <div className="flex flex-col">
                                 <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Paid to Driver</label>
                                 <input 
                                   type="number"
                                   value={alloc.paidToDriver || ''}
                                   onChange={(e) => handleAllocationChange(group.consigneeId, 'paidToDriver', e.target.value)}
                                   placeholder="0.00"
                                   className="w-24 h-10 px-2 bg-white border border-slate-200 rounded-md text-sm font-black text-fuchsia-700 focus:border-fuchsia-500 focus:outline-none focus:ring-2 focus:ring-fuchsia-500/20"
                                 />
                               </div>
                               <div className="flex flex-col">
                                 <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Paid to Us (Bank)</label>
                                 <input 
                                   type="number"
                                   value={alloc.paidToTransport || ''}
                                   onChange={(e) => handleAllocationChange(group.consigneeId, 'paidToTransport', e.target.value)}
                                   placeholder="0.00"
                                   className="w-24 h-10 px-2 bg-white border border-slate-200 rounded-md text-sm font-black text-emerald-700 focus:border-emerald-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
                                 />
                               </div>
                               <button 
                                 onClick={() => handleFullToDriver(group.consigneeId, group.totalFreightDue)}
                                 className="mt-4 px-3 py-2 bg-fuchsia-100 text-fuchsia-700 hover:bg-fuchsia-200 rounded-md text-[10px] font-black transition-colors"
                                 title="Fill full freight to driver"
                               >
                                 MAX
                               </button>
                             </div>
                           </div>
                           
                           {/* Expanded GC Details */}
                           {isExpanded && (
                             <div className="bg-slate-50 border-t border-slate-100 p-4 pl-5">
                               <div className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">Individual GCs</div>
                               <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                 {group.gcs.map(gc => (
                                   <div key={gc.id} className="bg-white border border-slate-200 rounded-lg p-3 flex justify-between items-center shadow-sm">
                                     <div>
                                       <div className="font-black text-slate-700">{gc.gcNumber}</div>
                                       <div className="text-[10px] font-bold text-slate-400 uppercase">{gc.freightType}</div>
                                     </div>
                                     <div className="font-black text-slate-800">₹{gc.freightTotal}</div>
                                   </div>
                                 ))}
                               </div>
                             </div>
                           )}
                         </div>
                       );
                     })}
                   </div>

                   {/* Master Settlement Calculator Box */}
                   <div className="bg-slate-900 rounded-2xl p-6 text-white shadow-xl">
                      <h3 className="text-sm font-black text-slate-400 uppercase tracking-wider mb-4 flex items-center gap-2">
                        <Coins size={16} /> Settlement Summary
                      </h3>
                      
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
                        <div>
                          <div className="text-slate-400 text-xs font-bold mb-1">Trip Balance Due</div>
                          <div className="text-2xl font-black">₹ {tripBalance.toFixed(2)}</div>
                        </div>
                        <div>
                          <div className="text-slate-400 text-xs font-bold mb-1">Driver Collected</div>
                          <div className="text-2xl font-black text-fuchsia-400">₹ {totalPaidToDriver.toFixed(2)}</div>
                        </div>
                        <div>
                          <div className="text-slate-400 text-xs font-bold mb-1">Company Collected</div>
                          <div className="text-2xl font-black text-emerald-400">₹ {totalPaidToUs.toFixed(2)}</div>
                        </div>
                      </div>

                      <div className="h-px bg-slate-700 w-full mb-6" />

                      <div className="flex justify-between items-end">
                        <div>
                          {isCrossing ? (
                            <div className="bg-emerald-500/20 border border-emerald-500/30 px-4 py-3 rounded-xl inline-block">
                              <div className="text-emerald-400 text-xs font-bold uppercase tracking-wider mb-0.5">Crossing Amount</div>
                              <div className="text-3xl font-black text-emerald-400">Driver gives you: ₹{absoluteDifference.toFixed(2)}</div>
                            </div>
                          ) : isReturn ? (
                            <div className="bg-rose-500/20 border border-rose-500/30 px-4 py-3 rounded-xl inline-block">
                              <div className="text-rose-400 text-xs font-bold uppercase tracking-wider mb-0.5">Return Amount</div>
                              <div className="text-3xl font-black text-rose-400">You pay Driver: ₹{absoluteDifference.toFixed(2)}</div>
                            </div>
                          ) : (
                            <div className="bg-slate-800 border border-slate-700 px-4 py-3 rounded-xl inline-block">
                              <div className="text-slate-400 text-xs font-bold uppercase tracking-wider mb-0.5">Perfect Settlement</div>
                              <div className="text-3xl font-black text-slate-300">Settled Even: ₹0.00</div>
                            </div>
                          )}
                        </div>

                        <button 
                          onClick={handleSettleTrip}
                          disabled={loading}
                          className="px-8 h-14 bg-fuchsia-600 hover:bg-fuchsia-500 disabled:bg-slate-700 text-white rounded-xl font-black text-lg shadow-[0_0_20px_rgba(192,38,211,0.4)] transition-all flex items-center gap-2"
                        >
                          <CheckCircle size={20} />
                          {loading ? 'Processing...' : 'Finalize Settlement'}
                        </button>
                      </div>
                   </div>
                </div>
              )}
           </div>
        </div>
      </div>

      <TrackingModal 
        isOpen={isTrackingModalOpen} 
        onClose={() => setIsTrackingModalOpen(false)} 
        vehicleNumber={trackingVehicleNumber}
      />
    </div>
  );
}
