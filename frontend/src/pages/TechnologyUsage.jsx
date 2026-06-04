import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Server, Database, Activity, Cpu, Cloud, Smartphone, Zap } from 'lucide-react';
import { Card } from '../components/ui/Card';

const TechCard = ({ icon: Icon, title, description, status, type, link }) => (
  <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-200 hover:shadow-md transition-all relative overflow-hidden group">
    <div className={`absolute top-0 right-0 w-16 h-16 rounded-bl-full opacity-10 transition-transform group-hover:scale-110 ${
      type === 'db' ? 'bg-blue-500' : 
      type === 'api' ? 'bg-purple-500' : 
      type === 'cloud' ? 'bg-sky-500' : 'bg-emerald-500'
    }`} />
    
    <div className="flex justify-between items-start mb-4">
      <div className={`p-3 rounded-xl inline-flex ${
        type === 'db' ? 'bg-blue-50 text-blue-600' : 
        type === 'api' ? 'bg-purple-50 text-purple-600' : 
        type === 'cloud' ? 'bg-sky-50 text-sky-600' : 'bg-emerald-50 text-emerald-600'
      }`}>
        <Icon size={24} />
      </div>
      <div className={`px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider ${
        status === 'Active' ? 'bg-emerald-100 text-emerald-700' : 
        status === 'Prepaid' ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-700'
      }`}>
        {status}
      </div>
    </div>
    
    <h3 className="text-lg font-black text-slate-800 tracking-tight">{title}</h3>
    <p className="text-xs font-medium text-slate-500 mt-1 mb-4 leading-relaxed">{description}</p>
    
    {link && (
      <a href={link} target="_blank" rel="noreferrer" className="text-xs font-bold text-indigo-600 hover:text-indigo-800 flex items-center gap-1 group-hover:underline">
        Manage Dashboard &rarr;
      </a>
    )}
  </div>
);

export default function TechnologyUsage() {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      const data = await api.get('/usage/stats');
      setStats(data);
    } catch (err) {
      console.error('Failed to fetch API stats:', err);
    } finally {
      setLoading(false);
    }
  };

  const getTodayStats = () => {
    if (!stats) return { count: 0, cost: 0 };
    const today = new Date().toISOString().split('T')[0];
    return stats.daily[today] || { count: 0, cost: 0 };
  };

  const getThisMonthStats = () => {
    if (!stats) return { count: 0, cost: 0 };
    const month = new Date().toISOString().substring(0, 7);
    return stats.monthly[month] || { count: 0, cost: 0 };
  };

  return (
    <div className="max-w-6xl mx-auto space-y-6 pb-12" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <div className="bg-slate-800 text-white p-2.5 rounded-xl">
            <Cpu size={24} />
          </div>
          <div>
            <h1 className="text-2xl font-black text-slate-800 tracking-tight">Technology & API Usage</h1>
            <p className="text-sm font-medium text-slate-500">Monitor your cloud infrastructure, databases, and prepaid API costs.</p>
          </div>
        </div>
      </div>

      {/* METRICS ROW */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card className="p-5 bg-gradient-to-br from-indigo-600 to-indigo-800 text-white border-none shadow-lg shadow-indigo-900/20">
          <div className="flex items-center gap-2 text-indigo-200 mb-2 font-bold text-xs uppercase tracking-wider">
            <Activity size={16} /> Today's API Usage
          </div>
          <div className="flex items-end justify-between">
            <div>
              <span className="text-4xl font-black">{getTodayStats().count}</span>
              <span className="text-indigo-200 ml-2 font-medium">Calls</span>
            </div>
            <div className="text-right">
              <span className="text-xl font-bold">₹{getTodayStats().cost.toFixed(2)}</span>
            </div>
          </div>
        </Card>
        
        <Card className="p-5 bg-white border border-slate-200 shadow-sm">
          <div className="flex items-center gap-2 text-slate-500 mb-2 font-bold text-xs uppercase tracking-wider">
            <Zap size={16} className="text-amber-500" /> This Month
          </div>
          <div className="flex items-end justify-between">
            <div>
              <span className="text-4xl font-black text-slate-800">{getThisMonthStats().count}</span>
              <span className="text-slate-500 ml-2 font-medium">Calls</span>
            </div>
            <div className="text-right">
              <span className="text-xl font-bold text-rose-600">₹{getThisMonthStats().cost.toFixed(2)}</span>
            </div>
          </div>
        </Card>

        <Card className="p-5 bg-white border border-slate-200 shadow-sm">
          <div className="flex items-center gap-2 text-slate-500 mb-2 font-bold text-xs uppercase tracking-wider">
            <Database size={16} className="text-emerald-500" /> All-Time Database
          </div>
          <div className="flex items-end justify-between">
            <div>
              <span className="text-4xl font-black text-slate-800">{stats?.totalCost ? Math.round(stats.totalCost) : '0'}</span>
              <span className="text-slate-500 ml-2 font-medium">Total ₹ Cost</span>
            </div>
          </div>
        </Card>
      </div>

      {/* ARCHITECTURE GRID */}
      <h2 className="text-lg font-black text-slate-800 tracking-tight mt-8 mb-4">Cloud Infrastructure Architecture</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        <TechCard 
          icon={Database} 
          title="Neon PostgreSQL" 
          description="Serverless Cloud Database holding all your ERP records (Godowns, Consignors, GCs, etc). Highly scalable and blazingly fast."
          status="Active" 
          type="db"
          link="https://console.neon.tech"
        />
        <TechCard 
          icon={Server} 
          title="Render Backend" 
          description="Node.js Express Server handling all logical processing, security, routing, and API connections for the ERP."
          status="Active" 
          type="cloud"
          link="https://dashboard.render.com"
        />
        <TechCard 
          icon={Cloud} 
          title="Vercel Frontend" 
          description="Global Edge Network hosting the React UI. Distributes your app to servers worldwide for instant loading."
          status="Active" 
          type="cloud"
          link="https://vercel.com"
        />
        <TechCard 
          icon={Activity} 
          title="Whitebooks API" 
          description="Fetches E-Way Bill Details, verifies VAHAN RC statuses, and auto-fills GSTIN data. Pay-per-use prepaid wallet."
          status="Prepaid" 
          type="api"
          link="https://api.whitebooks.in"
        />
        <TechCard 
          icon={Smartphone} 
          title="Tesseract OCR" 
          description="Runs on-device AI for instant E-Way Bill Barcode scanning without sending images to the cloud."
          status="Active" 
          type="app"
        />
      </div>

      {/* RECENT API LOGS */}
      <Card className="bg-white rounded-2xl shadow-sm border border-slate-200 mt-8 overflow-hidden">
        <div className="p-4 border-b border-slate-100 bg-slate-50/50">
          <h3 className="font-bold text-sm text-slate-800">Recent API Execution Logs</h3>
        </div>
        <div className="overflow-x-auto max-h-[400px] overflow-y-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-[10px] font-extrabold text-slate-500 uppercase tracking-wider sticky top-0 bg-white border-b border-slate-100 z-10">
              <tr>
                <th className="p-4">Timestamp</th>
                <th className="p-4">Provider</th>
                <th className="p-4">API Name</th>
                <th className="p-4">Status</th>
                <th className="p-4 text-right">Cost (₹)</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50 font-medium">
              {stats?.recent?.length > 0 ? stats.recent.map(log => (
                <tr key={log.id} className="hover:bg-slate-50/50">
                  <td className="p-4 text-slate-500 text-xs">
                    {new Date(log.timestamp).toLocaleString()}
                  </td>
                  <td className="p-4 text-slate-800 font-bold">{log.provider}</td>
                  <td className="p-4 text-indigo-700">{log.apiName}</td>
                  <td className="p-4">
                    <span className={`px-2 py-0.5 rounded-sm text-[10px] font-black uppercase ${log.status === 'Success' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                      {log.status}
                    </span>
                  </td>
                  <td className="p-4 text-right font-bold text-slate-700">
                    {log.cost > 0 ? `₹${log.cost.toFixed(2)}` : 'Free'}
                  </td>
                </tr>
              )) : (
                <tr>
                  <td colSpan="5" className="p-8 text-center text-slate-400">No API calls recorded yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </Card>
      
    </div>
  );
}
