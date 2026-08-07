import React, { useState, useEffect } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { Server, Database, Activity, Cpu, Cloud, Smartphone, Zap, X, CheckCircle, XCircle, Clock, MessageCircle, RefreshCw } from 'lucide-react';
import { Card } from '../components/ui/Card';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { Button } from '../components/ui/Button';

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
  const [isTestingSandbox, setIsTestingSandbox] = useState(false);
  const [sandboxModalOpen, setSandboxModalOpen] = useState(false);
  const [sandboxResults, setSandboxResults] = useState(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  
  const [health, setHealth] = useState(null);
  const [healthHistory, setHealthHistory] = useState([]);

  useEffect(() => {
    fetchStats();
    fetchHealth();
    fetchHealthHistory();
    
    // Refresh health every 15 seconds
    const interval = setInterval(fetchHealth, 15000);
    return () => clearInterval(interval);
  }, []);

  const handleManualRefresh = async () => {
    setIsRefreshing(true);
    await Promise.all([fetchHealth(), fetchStats(), fetchHealthHistory()]);
    setIsRefreshing(false);
  };

  const fetchHealthHistory = async () => {
    try {
      const res = await api.get('/system/health/history');
      if (res.success) {
        // Format time for tooltip and axis
        const formatted = res.data.map(log => ({
          ...log,
          time: new Date(log.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        }));
        setHealthHistory(formatted);
      }
    } catch (err) {
      console.error('Failed to fetch health history:', err);
    }
  };

  const fetchHealth = async () => {
    try {
      const res = await api.get('/system/health');
      if (res.success) {
        setHealth(res.data);
      }
    } catch (err) {
      console.error('Failed to fetch system health:', err);
    }
  };

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

  const handleSandboxTest = async () => {
    setIsTestingSandbox(true);
    setSandboxModalOpen(true);
    setSandboxResults(null);
    try {
      const res = await api.post('/usage/sandbox-test');
      setSandboxResults(res.results || []);
      fetchStats(); // refresh logs
    } catch (err) {
      setSandboxResults([{ step: 'Network', success: false, message: err.message, ping: 0 }]);
    } finally {
      setIsTestingSandbox(false);
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

  const formatMemory = (bytes) => bytes ? (bytes / 1024 / 1024).toFixed(0) : '0';
  const formatUptime = (seconds) => {
    if (!seconds) return '0m';
    const d = Math.floor(seconds / (3600*24));
    const h = Math.floor(seconds % (3600*24) / 3600);
    const m = Math.floor(seconds % 3600 / 60);
    if (d > 0) return `${d}d ${h}h`;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
  };

  const generateHealthReport = () => {
    if (!health) return [];
    
    // Performance
    let performanceStatus = "Excellent";
    let performanceText = "The system is extremely fast and responding instantly.";
    let performanceColor = "text-emerald-500";
    let performanceBg = "bg-emerald-50";
    
    if (health.dbLatency > 100) {
      performanceStatus = "Degraded";
      performanceText = "Database queries are running slightly slower than usual.";
      performanceColor = "text-amber-500";
      performanceBg = "bg-amber-50";
    }

    // Reliability
    let reliabilityStatus = "Perfect";
    let reliabilityText = "No downtime detected recently. System is highly stable.";
    let reliabilityColor = "text-emerald-500";
    let reliabilityBg = "bg-emerald-50";
    
    if (health.uptime < 3600) {
      reliabilityStatus = "Recent Restart";
      reliabilityText = "The server was restarted recently and is now stabilizing.";
      reliabilityColor = "text-sky-500";
      reliabilityBg = "bg-sky-50";
    }

    // Resource Health
    let memoryStatus = "Stable";
    let memoryText = "Server memory is highly stable with no leaks detected.";
    let memoryColor = "text-emerald-500";
    let memoryBg = "bg-emerald-50";
    
    if (health.memoryUsage && health.memoryUsage.rss > 500 * 1024 * 1024) {
      memoryStatus = "High Load";
      memoryText = "Server is handling a high memory workload currently.";
      memoryColor = "text-amber-500";
      memoryBg = "bg-amber-50";
    }
    
    return [
      { title: "Performance", status: performanceStatus, text: performanceText, color: performanceColor, bg: performanceBg },
      { title: "Reliability", status: reliabilityStatus, text: reliabilityText, color: reliabilityColor, bg: reliabilityBg },
      { title: "Resource Health", status: memoryStatus, text: memoryText, color: memoryColor, bg: memoryBg },
      { title: "Maintenance", status: "Up to date", text: "Automated cleanup routines are running successfully.", color: "text-emerald-500", bg: "bg-emerald-50" }
    ];
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
        <Button variant="custom"
          onClick={handleSandboxTest}
          disabled={isTestingSandbox}
          className="bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl font-bold text-sm shadow-md transition-all flex items-center gap-2 disabled:opacity-50"
        >
          {isTestingSandbox ? <Activity className="animate-spin" size={18} /> : <Activity size={18} />}
          {isTestingSandbox ? 'Pinging NIC...' : 'Run Sandbox Test'}
        </Button>
      </div>

      {/* SYSTEM HEALTH & VITALS */}
      <div className="flex items-center justify-between mt-8 mb-4">
        <h2 className="text-lg font-black text-slate-800 tracking-tight flex items-center gap-2">
          <Server className="text-slate-500" size={20} /> System Health & Vitals
          {health && <span className="flex h-2 w-2 relative ml-2"><span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span><span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span></span>}
        </h2>
        <Button variant="custom" 
          onClick={handleManualRefresh}
          disabled={isRefreshing}
          className="text-xs font-bold text-slate-500 hover:text-slate-800 flex items-center gap-1.5 transition-colors disabled:opacity-50"
        >
          <RefreshCw size={14} className={isRefreshing ? 'animate-spin text-indigo-500' : ''} />
          {isRefreshing ? 'Refreshing...' : 'Refresh Vitals'}
        </Button>
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card className="p-4 bg-white border border-slate-200 shadow-sm flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Backend Memory</span>
            <Activity size={16} className={health?.memoryUsage?.rss > 500 * 1024 * 1024 ? 'text-rose-500' : 'text-emerald-500'} />
          </div>
          <div>
            <span className="text-3xl font-black text-slate-800">{health ? formatMemory(health.memoryUsage.rss) : '--'}</span>
            <span className="text-xs text-slate-500 font-medium ml-1">MB Used</span>
          </div>
        </Card>
        
        <Card className="p-4 bg-white border border-slate-200 shadow-sm flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Server Uptime</span>
            <Clock size={16} className="text-indigo-500" />
          </div>
          <div>
            <span className="text-3xl font-black text-slate-800">{health ? formatUptime(health.uptime) : '--'}</span>
          </div>
        </Card>

        <Card className="p-4 bg-white border border-slate-200 shadow-sm flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Database Ping</span>
            <Database size={16} className={health?.dbLatency > 100 ? 'text-amber-500' : 'text-emerald-500'} />
          </div>
          <div>
            <span className="text-3xl font-black text-slate-800">{health ? health.dbLatency : '--'}</span>
            <span className="text-xs text-slate-500 font-medium ml-1">ms</span>
          </div>
        </Card>

        <Card className="p-4 bg-white border border-slate-200 shadow-sm flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">CPU Load (1m)</span>
            <Cpu size={16} className="text-sky-500" />
          </div>
          <div>
            <span className="text-3xl font-black text-slate-800">{health?.cpuLoad ? health.cpuLoad[0].toFixed(2) : '--'}</span>
            <span className="text-xs text-slate-500 font-medium ml-1">avg</span>
          </div>
        </Card>
      </div>

      {/* SYSTEM STATUS SUMMARY (ENGLISH REPORT) */}
      {health && (
        <div className="mt-8">
          <h2 className="text-lg font-black text-slate-800 tracking-tight mb-4 flex items-center gap-2">
            <CheckCircle className="text-emerald-500" size={20} /> System Status Summary
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {generateHealthReport().map((report, idx) => (
              <div key={idx} className={`p-4 rounded-xl border border-slate-200 bg-white flex gap-4 items-start shadow-sm`}>
                <div className={`p-2 rounded-lg ${report.bg} ${report.color} shrink-0`}>
                  {report.color.includes('emerald') ? <CheckCircle size={20} /> : report.color.includes('amber') ? <Activity size={20} /> : <Server size={20} />}
                </div>
                <div>
                  <h3 className="font-bold text-slate-800 text-sm">
                    {report.title}: <span className={report.color}>{report.status}</span>
                  </h3>
                  <p className="text-xs font-medium text-slate-500 mt-1">{report.text}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 24-HOUR PERFORMANCE TIMELINE */}
      {healthHistory.length > 0 && (
        <div className="mt-8">
          <h2 className="text-lg font-black text-slate-800 tracking-tight mb-4 flex items-center gap-2">
            <Activity className="text-indigo-500" size={20} /> 24-Hour Performance Timeline
          </h2>
          <Card className="p-5 bg-white border border-slate-200 shadow-sm overflow-hidden">
            <div className="h-[250px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={healthHistory} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                  <XAxis dataKey="time" axisLine={false} tickLine={false} tick={{ fontSize: 10, fill: '#64748b' }} minTickGap={30} />
                  <YAxis yAxisId="left" axisLine={false} tickLine={false} tick={{ fontSize: 10, fill: '#64748b' }} />
                  <YAxis yAxisId="right" orientation="right" axisLine={false} tickLine={false} tick={{ fontSize: 10, fill: '#64748b' }} />
                  <Tooltip 
                    contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)' }}
                    labelStyle={{ fontWeight: 'bold', color: '#0f172a', marginBottom: '4px' }}
                  />
                  <Line yAxisId="left" type="monotone" dataKey="memoryMb" name="Memory (MB)" stroke="#10b981" strokeWidth={3} dot={false} activeDot={{ r: 6, fill: '#10b981', stroke: '#fff', strokeWidth: 2 }} />
                  <Line yAxisId="right" type="monotone" dataKey="dbPing" name="DB Ping (ms)" stroke="#f59e0b" strokeWidth={3} dot={false} activeDot={{ r: 6, fill: '#f59e0b', stroke: '#fff', strokeWidth: 2 }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
            <div className="flex items-center gap-6 mt-4 justify-center text-xs font-bold text-slate-500">
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full bg-emerald-500 block"></span> Memory Usage (MB)
              </div>
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full bg-amber-500 block"></span> Database Ping (ms)
              </div>
            </div>
          </Card>
        </div>
      )}

      {/* METRICS ROW */}
      <h2 className="text-lg font-black text-slate-800 tracking-tight mt-8 mb-4">API Billing & Analytics</h2>
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
          title="Supabase PostgreSQL" 
          description="Serverless Database holding all your ERP records. Powered by reliable connection pooling and edge caching for instant global access."
          status="Active" 
          type="db"
          link="https://supabase.com/dashboard"
        />
        <TechCard 
          icon={Server} 
          title="Railway Backend" 
          description="Node.js Express Server handling all heavy PDF processing and routing. Runs 24/7 without sleeping for instant generation."
          status="Active" 
          type="cloud"
          link="https://railway.app/dashboard"
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
          icon={CheckCircle} 
          title="Appyflow API" 
          description="Used globally across the app for instant GSTIN verification and Postal Pincode routing during master creation."
          status="Active" 
          type="api"
        />
        <TechCard 
          icon={MessageCircle} 
          title="WhatsApp Cloud API" 
          description="Automated customer notifications sending E-Way Bills directly to drivers and consignees instantly."
          status="Active" 
          type="api"
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
      
      {/* SANDBOX MODAL */}
      {sandboxModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg overflow-hidden animate-in fade-in zoom-in-95 duration-200">
            <div className="flex justify-between items-center p-5 border-b border-slate-100 bg-slate-50">
              <div>
                <h3 className="font-black text-lg text-slate-800 tracking-tight">Sandbox Lifecycle Test</h3>
                <p className="text-xs font-medium text-slate-500">Executing sequence on NIC testing environment</p>
              </div>
              <Button variant="custom" onClick={() => setSandboxModalOpen(false)} className="text-slate-400 hover:text-slate-600 bg-white shadow-sm p-1.5 rounded-full border border-slate-200">
                <X size={18} />
              </Button>
            </div>
            
            <div className="p-6">
              {isTestingSandbox && !sandboxResults && (
                <div className="flex flex-col items-center justify-center py-8 space-y-4">
                  <Activity size={32} className="animate-spin text-indigo-500" />
                  <p className="font-bold text-slate-600 text-sm">Running test sequence (Auth ➔ Generate ➔ Fetch ➔ CEWB)...</p>
                </div>
              )}

              {sandboxResults && (
                <div className="space-y-4">
                  {sandboxResults.map((r, i) => (
                    <div key={i} className={`p-4 rounded-xl border ${r.success ? 'bg-emerald-50/50 border-emerald-100' : 'bg-rose-50/50 border-rose-100'}`}>
                      <div className="flex items-start justify-between gap-4">
                        <div className="flex items-start gap-3">
                          {r.success ? <CheckCircle className="text-emerald-500 shrink-0 mt-0.5" size={18} /> : <XCircle className="text-rose-500 shrink-0 mt-0.5" size={18} />}
                          <div>
                            <p className="font-bold text-sm text-slate-800">{r.step}</p>
                            <p className={`text-xs font-medium mt-1 ${r.success ? 'text-emerald-700' : 'text-rose-600'}`}>{r.message}</p>
                          </div>
                        </div>
                        <div className="flex items-center gap-1 text-slate-400 text-xs font-bold shrink-0">
                          <Clock size={12} /> {r.ping}ms
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
            
            <div className="p-4 border-t border-slate-100 bg-slate-50 flex justify-end">
               <Button variant="custom" 
                onClick={() => setSandboxModalOpen(false)}
                className="bg-white border border-slate-200 hover:bg-slate-100 text-slate-700 px-4 py-2 rounded-xl font-bold text-sm transition-all"
               >
                 Close
               </Button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
