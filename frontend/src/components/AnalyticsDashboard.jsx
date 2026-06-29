import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { TrendingUp, Truck, Package, Activity, AlertCircle } from 'lucide-react';

export default function AnalyticsDashboard() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchAnalytics = async () => {
      try {
        const res = await api.get('/analytics/dashboard');
        setData(res);
      } catch (err) {
        setError(err.message || 'Failed to load analytics');
      } finally {
        setLoading(false);
      }
    };
    fetchAnalytics();
    
    // Refresh every 5 minutes
    const interval = setInterval(fetchAnalytics, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  if (loading) return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-100 p-6 flex items-center justify-center min-h-[160px] animate-pulse">
      <div className="flex flex-col items-center gap-2">
        <Activity size={24} className="text-indigo-400 animate-spin" />
        <span className="text-slate-400 text-sm font-bold">Loading Executive Analytics...</span>
      </div>
    </div>
  );

  if (error) return (
    <div className="bg-rose-50 rounded-2xl border border-rose-100 p-6 flex items-center justify-center min-h-[160px]">
      <div className="flex flex-col items-center gap-2 text-rose-500">
        <AlertCircle size={24} />
        <span className="text-sm font-bold">{error}</span>
      </div>
    </div>
  );

  if (!data) return null;

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden mb-6">
      <div className="px-6 py-4 border-b border-slate-100 bg-slate-50/50 flex justify-between items-center">
        <h2 className="font-black text-slate-800 flex items-center gap-2 text-lg">
          <TrendingUp className="text-indigo-600" size={20} />
          Executive Overview
        </h2>
        <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Real-Time Data</span>
      </div>
      
      <div className="p-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        
        {/* Today's Revenue */}
        <div className="bg-gradient-to-br from-indigo-500 to-indigo-600 rounded-xl p-5 text-white relative overflow-hidden shadow-lg shadow-indigo-200">
          <div className="relative z-10">
            <h3 className="text-indigo-100 text-xs font-black uppercase tracking-wider mb-1">Today's Revenue (BNG)</h3>
            <div className="text-3xl font-black mb-1">₹{data.dailyRevenue.toLocaleString('en-IN')}</div>
            <div className="text-indigo-200 text-sm font-medium flex items-center gap-1">
              <Package size={14} /> {data.dailyCount} GCs Generated
            </div>
          </div>
          <TrendingUp className="absolute -right-4 -bottom-4 w-24 h-24 text-white/10" />
        </div>

        {/* MTD Revenue */}
        <div className="bg-white rounded-xl p-5 border border-slate-100 relative overflow-hidden shadow-sm hover:shadow-md transition-shadow">
          <div className="relative z-10">
            <h3 className="text-slate-400 text-xs font-black uppercase tracking-wider mb-1">Month-to-Date</h3>
            <div className="text-3xl font-black text-slate-800 mb-1">₹{data.monthlyRevenue.toLocaleString('en-IN')}</div>
            <div className="text-emerald-500 text-sm font-medium flex items-center gap-1">
              {data.monthlyCount} Total GCs
            </div>
          </div>
        </div>

        {/* Logistics Status */}
        <div className="bg-white rounded-xl p-5 border border-slate-100 relative overflow-hidden shadow-sm hover:shadow-md transition-shadow">
          <div className="relative z-10">
            <h3 className="text-slate-400 text-xs font-black uppercase tracking-wider mb-1">Transit Status</h3>
            <div className="text-3xl font-black text-slate-800 mb-1">{data.activeTrucks}</div>
            <div className="text-amber-500 text-sm font-medium flex items-center gap-1">
              <Truck size={14} /> Active GDMs (Trucks)
            </div>
          </div>
        </div>

        {/* Branch Performance */}
        <div className="bg-white rounded-xl p-5 border border-slate-100 relative overflow-hidden shadow-sm hover:shadow-md transition-shadow">
          <div className="relative z-10">
            <h3 className="text-slate-400 text-xs font-black uppercase tracking-wider mb-2">Today's GC Volume</h3>
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-sm font-bold text-slate-600">MAIN</span>
                <span className="text-sm font-black text-slate-800">{data.branchStats.MAIN || 0}</span>
              </div>
              <div className="w-full bg-slate-100 h-1.5 rounded-full overflow-hidden">
                <div className="bg-indigo-500 h-full" style={{ width: `${((data.branchStats.MAIN || 0) / (data.dailyCount || 1)) * 100}%` }}></div>
              </div>
              
              <div className="flex items-center justify-between pt-1">
                <span className="text-sm font-bold text-slate-600">AP_BNG</span>
                <span className="text-sm font-black text-slate-800">{data.branchStats.AP_BNG || 0}</span>
              </div>
              <div className="w-full bg-slate-100 h-1.5 rounded-full overflow-hidden">
                <div className="bg-emerald-500 h-full" style={{ width: `${((data.branchStats.AP_BNG || 0) / (data.dailyCount || 1)) * 100}%` }}></div>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
