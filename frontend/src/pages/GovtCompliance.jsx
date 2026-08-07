import React, { useState, useEffect, useMemo } from 'react';
import { api } from '../api';
import { Loader2, ShieldAlert, PackageCheck, RefreshCw, Truck, FileText, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { Button } from '../components/ui/Button';

export default function GovtCompliance() {
  const [loading, setLoading] = useState(true);
  const [pendingGdms, setPendingGdms] = useState([]);
  const [selectedGdmIds, setSelectedGdmIds] = useState(new Set());
  
  const [isVerifying, setIsVerifying] = useState(false);
  const [isHealing, setIsHealing] = useState(false);
  const [isGeneratingCewb, setIsGeneratingCewb] = useState(false);
  const [activeVehicleNo, setActiveVehicleNo] = useState(null);

  // Fetch pending GDMs
  const fetchPendingGdms = async () => {
    try {
      setLoading(true);
      const branch = localStorage.getItem('activeBranch') || 'MAIN';
      const res = await api.get(`/gdms/pending-cewb?branch=${branch}`);
      setPendingGdms(res || []);
    } catch (err) {
      toast.error('Failed to fetch pending GDMs for compliance.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPendingGdms();
  }, []);

  // Handle Checkbox Selection
  const toggleSelection = (gdmId, vehicleNo) => {
    const newSelection = new Set(selectedGdmIds);
    if (newSelection.has(gdmId)) {
      newSelection.delete(gdmId);
      if (newSelection.size === 0) setActiveVehicleNo(null);
    } else {
      // Ensure all selected GDMs belong to the SAME vehicle
      if (activeVehicleNo && activeVehicleNo !== vehicleNo) {
        toast.error('You can only select GDMs for the same Lorry at once.');
        return;
      }
      newSelection.add(gdmId);
      setActiveVehicleNo(vehicleNo);
    }
    setSelectedGdmIds(newSelection);
  };

  const selectedGdms = useMemo(() => {
    return pendingGdms.filter(gdm => selectedGdmIds.has(gdm.id));
  }, [pendingGdms, selectedGdmIds]);

  const allSelectedGcs = useMemo(() => {
    let gcs = [];
    selectedGdms.forEach(gdm => {
      if (gdm.gcs) {
        gcs = [...gcs, ...gdm.gcs.map(gc => ({ ...gc, gdmNumber: gdm.gdmNumber, companyString: gc.gcNumber?.startsWith('BELL') ? 'BELL' : 'AP' }))];
      }
    });
    return gcs;
  }, [selectedGdms]);

  // Bulk Verify
  const handleVerify = async () => {
    if (allSelectedGcs.length === 0) return;
    setIsVerifying(true);
    try {
      const ewbsToVerify = allSelectedGcs
        .filter(gc => gc.ewbNumber)
        .map(gc => ({ ewbNo: gc.ewbNumber, company: gc.companyString }));
        
      if (ewbsToVerify.length === 0) {
         toast.error("No E-Way Bills found to verify.");
         return;
      }
      const res = await api.post('/ewaybill/bulk-verify', { ewbs: ewbsToVerify });
      toast.success(`Verification complete. Statuses updated.`);
      // Re-fetch to see updated DB statuses if we saved them, but here we just show toast for now.
    } catch (err) {
      toast.error('Verification failed: ' + err.message);
    } finally {
      setIsVerifying(false);
    }
  };

  // Bulk Heal
  const handleHeal = async () => {
    if (allSelectedGcs.length === 0 || !activeVehicleNo) return;
    setIsHealing(true);
    const toastId = toast.loading('Initiating Auto-Healing...');
    try {
      const vNo = activeVehicleNo.replace(/[^A-Z0-9]/gi, '');
      const res = await api.post('/ewaybill/bulk-heal', { gcs: allSelectedGcs, vehicleNo: vNo });
      toast.success('Successfully healed all E-Way Bills!', { id: toastId });
      fetchPendingGdms(); // Refresh data to show private marks/EWB numbers generated
    } catch (err) {
      toast.error('Heal failed: ' + (err.error || err.message), { id: toastId });
    } finally {
      setIsHealing(false);
    }
  };

  // Generate CEWB
  const handleGenerateCEWB = async () => {
    if (allSelectedGcs.length === 0 || !activeVehicleNo) return;
    
    // Group GCs by company because CEWB generation is per company (AP/BELL)
    const validEwbsAP = allSelectedGcs.filter(gc => gc.companyString === 'AP' && gc.privateMark).map(gc => gc.privateMark);
    const validEwbsBELL = allSelectedGcs.filter(gc => gc.companyString === 'BELL' && gc.privateMark).map(gc => gc.privateMark);
    
    if (validEwbsAP.length === 0 && validEwbsBELL.length === 0) {
      toast.error('No valid E-Way Bills found. Please Auto-Heal first.');
      return;
    }

    setIsGeneratingCewb(true);
    const toastId = toast.loading('Generating Master CEWB...');
    
    try {
      const vNo = activeVehicleNo.replace(/[^A-Z0-9]/gi, '');
      const basePayload = {
        vehicleNo: vNo,
        fromPlace: 'Sivakasi',
        transDocNo: `TRP-${Math.floor(Date.now()/1000)}`, // Dummy doc no for trip
        transDocDate: new Date().toLocaleDateString('en-GB')
      };

      const generatedCewbs = [];
      
      // AP CEWB
      if (validEwbsAP.length > 0) {
        const resAP = await api.post(`/ewaybill/cewb?company=AP`, { ...basePayload, ewbNos: validEwbsAP });
        if (resAP && resAP.cEwbNo) generatedCewbs.push(`AP: ${resAP.cEwbNo}`);
      }
      
      // BELL CEWB
      if (validEwbsBELL.length > 0) {
        const resBELL = await api.post(`/ewaybill/cewb?company=BELL`, { ...basePayload, ewbNos: validEwbsBELL });
        if (resBELL && resBELL.cEwbNo) generatedCewbs.push(`BELL: ${resBELL.cEwbNo}`);
      }
      
      if (generatedCewbs.length > 0) {
        const cewbString = generatedCewbs.join(' | ');
        // Attach to GDMs
        await api.post('/gdms/attach-master-cewb', {
           gdmIds: Array.from(selectedGdmIds),
           cewbNumber: cewbString
        });
        toast.success(`Successfully attached Master CEWB: ${cewbString}`, { id: toastId });
        setSelectedGdmIds(new Set());
        setActiveVehicleNo(null);
        fetchPendingGdms();
      } else {
         toast.error('Failed to generate CEWBs.', { id: toastId });
      }
      
    } catch (err) {
      toast.error('CEWB Generation failed: ' + (err.error || err.message), { id: toastId });
    } finally {
      setIsGeneratingCewb(false);
    }
  };

  return (
    <div className="flex flex-col flex-1 w-full h-full bg-slate-100 overflow-hidden" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      <div className="bg-white border-b border-slate-200 p-4 shrink-0 z-20 shadow-sm flex justify-between items-center">
        <div>
          <h1 className="font-black text-slate-800 text-xl flex items-center gap-2"><ShieldAlert className="text-sky-600" /> Govt Compliance Hub</h1>
          <p className="text-xs font-bold text-slate-500 mt-0.5">Manage E-Way Bills and Generate Master CEWBs for Dispatches</p>
        </div>
        <div className="flex items-center gap-4">
          <Button variant="custom" onClick={fetchPendingGdms} className="p-2 bg-slate-50 hover:bg-slate-100 rounded-lg border border-slate-200 transition-colors">
            <RefreshCw size={16} className={`text-slate-600 ${loading ? 'animate-spin' : ''}`} />
          </Button>
        </div>
      </div>

      <div className="flex-1 flex flex-col md:flex-row overflow-hidden">
        
        {/* PANEL 1: Pending GDMs */}
        <div className="w-full md:w-1/3 bg-white border-r border-slate-200 flex flex-col h-full z-10 shadow-sm">
          <div className="p-4 border-b border-slate-100 bg-slate-50/50">
            <h2 className="font-bold text-sm text-slate-700 flex items-center gap-2"><Truck size={16} /> Pending GDMs Queue</h2>
          </div>
          <div className="flex-1 overflow-y-auto p-3 custom-scrollbar space-y-2">
            {loading && pendingGdms.length === 0 ? (
              <div className="flex justify-center p-10"><Loader2 className="animate-spin text-slate-400" /></div>
            ) : pendingGdms.length === 0 ? (
              <div className="text-center p-10 text-slate-400 font-semibold text-sm border-2 border-dashed border-slate-200 rounded-xl">
                No Pending GDMs found.
              </div>
            ) : (
              pendingGdms.map(gdm => {
                const vehicleNo = gdm.vehicle?.vehicleNumber || 'UNKNOWN';
                const isSelected = selectedGdmIds.has(gdm.id);
                // Disable if another vehicle is active
                const isDisabled = activeVehicleNo && activeVehicleNo !== vehicleNo;

                return (
                  <label key={gdm.id} className={`flex items-start gap-3 p-3 rounded-xl border-2 transition-all cursor-pointer ${isSelected ? 'border-sky-500 bg-sky-50 shadow-sm' : isDisabled ? 'border-slate-100 bg-slate-50 opacity-50 cursor-not-allowed' : 'border-slate-200 bg-white hover:border-sky-300'}`}>
                    <input 
                      type="checkbox" 
                      className="mt-1 w-4 h-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500 cursor-pointer"
                      checked={isSelected}
                      disabled={isDisabled}
                      onChange={() => toggleSelection(gdm.id, vehicleNo)}
                    />
                    <div className="flex-1">
                      <div className="flex justify-between items-center mb-1">
                        <span className="font-black text-slate-800 text-sm">{gdm.gdmNumber}</span>
                        <span className="text-[10px] font-bold text-slate-400 bg-slate-100 px-2 py-0.5 rounded">{gdm.date ? new Date(gdm.date).toLocaleDateString('en-GB') : ''}</span>
                      </div>
                      <div className="flex justify-between items-end mt-2">
                         <span className="text-xs font-bold text-slate-600 flex items-center gap-1"><Truck size={12} /> {vehicleNo}</span>
                         <span className="text-[10px] font-bold text-slate-500">{gdm.gcs?.length || 0} GCs</span>
                      </div>
                    </div>
                  </label>
                );
              })
            )}
          </div>
        </div>

        {/* PANEL 2: Staging Area */}
        <div className="w-full md:w-2/3 bg-slate-50 flex flex-col h-full">
          <div className="p-4 border-b border-slate-200 bg-white shadow-sm shrink-0">
             <div className="flex justify-between items-center">
                <div>
                  <h2 className="font-bold text-slate-800 flex items-center gap-2 text-lg"><FileText size={18} className="text-emerald-600"/> CEWB Staging Area</h2>
                  <p className="text-xs font-semibold text-slate-500 mt-1">
                    {activeVehicleNo ? `Lorry: ${activeVehicleNo}` : 'Select GDMs from the queue to bundle them.'}
                  </p>
                </div>
                {activeVehicleNo && (
                   <span className="bg-emerald-100 text-emerald-800 px-3 py-1 rounded-md text-xs font-black shadow-sm uppercase tracking-wider border border-emerald-200">
                     {allSelectedGcs.length} Consignments Ready
                   </span>
                )}
             </div>
          </div>
          
          <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
             {allSelectedGcs.length === 0 ? (
                <div className="h-full flex flex-col items-center justify-center text-slate-400">
                   <PackageCheck size={48} className="opacity-20 mb-4" />
                   <h3 className="font-bold text-lg text-slate-500">No GCs in Staging</h3>
                   <p className="text-sm">Check boxes on the left to add items.</p>
                </div>
             ) : (
                <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                   <table className="w-full text-left border-collapse">
                      <thead>
                        <tr className="bg-slate-100 text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-200">
                           <th className="p-3 pl-4">GC Number</th>
                           <th className="p-3">GDM Number</th>
                           <th className="p-3">EWB No (Private Mark)</th>
                           <th className="p-3">Consignee</th>
                        </tr>
                      </thead>
                      <tbody className="text-sm font-semibold text-slate-700 divide-y divide-slate-100">
                         {allSelectedGcs.map(gc => (
                            <tr key={gc.id} className="hover:bg-slate-50">
                               <td className="p-3 pl-4 text-indigo-700">{gc.gcNumber}</td>
                               <td className="p-3 text-slate-500 text-xs">{gc.gdmNumber}</td>
                               <td className="p-3">
                                  {gc.privateMark ? (
                                     <span className="font-mono text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">
                                        {gc.privateMark}
                                     </span>
                                  ) : (
                                     <span className="text-rose-500 text-xs bg-rose-50 px-2 py-0.5 rounded border border-rose-100">Missing</span>
                                  )}
                               </td>
                               <td className="p-3 text-xs truncate max-w-[150px]">{gc.consignee?.name || 'N/A'}</td>
                            </tr>
                         ))}
                      </tbody>
                   </table>
                </div>
             )}
          </div>

          {/* ACTION PANEL FOOTER */}
          <div className="p-4 bg-white border-t border-slate-200 shrink-0 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)]">
             <div className="flex gap-3 max-w-[900px] mx-auto">
                <Button variant="custom" 
                  onClick={handleVerify}
                  disabled={allSelectedGcs.length === 0 || isVerifying || isHealing || isGeneratingCewb}
                  className="flex-1 h-12 bg-sky-50 text-sky-700 hover:bg-sky-100 disabled:opacity-50 border border-sky-200 rounded-xl font-bold text-sm transition-all flex items-center justify-center gap-2 shadow-sm"
                >
                  {isVerifying ? <Loader2 size={16} className="animate-spin" /> : <ShieldAlert size={16} />}
                  Verify Status
                </Button>
                <Button variant="custom" 
                  onClick={handleHeal}
                  disabled={allSelectedGcs.length === 0 || isVerifying || isHealing || isGeneratingCewb}
                  className="flex-1 h-12 bg-amber-500 text-white hover:bg-amber-400 disabled:opacity-50 rounded-xl font-bold text-sm transition-all flex items-center justify-center gap-2 shadow-sm"
                >
                  {isHealing ? <Loader2 size={16} className="animate-spin" /> : <RefreshCw size={16} />}
                  Auto-Heal EWBs
                </Button>
                <Button variant="custom" 
                  onClick={handleGenerateCEWB}
                  disabled={allSelectedGcs.length === 0 || isVerifying || isHealing || isGeneratingCewb}
                  className="flex-[1.5] h-12 bg-emerald-600 text-white hover:bg-emerald-500 disabled:opacity-50 rounded-xl font-black text-sm transition-all flex items-center justify-center gap-2 shadow-md transform active:scale-[0.98]"
                >
                  {isGeneratingCewb ? <Loader2 size={16} className="animate-spin" /> : <PackageCheck size={16} />}
                  Generate Master CEWB
                </Button>
             </div>
          </div>
        </div>

      </div>
    </div>
  );
}
